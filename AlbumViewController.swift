//
//  AlbumViewController.swift
//  SohuAuto
//
//  Created by 郭彬 on 16/9/27.
//  Copyright © 2016年 WuJason. All rights reserved.
//

import UIKit
import RxSwift
import ObjectMapper

class AlbumViewController: BaseViewController {
    
    typealias CompleteClosure = (Error?) -> Void            //定义一个闭包
    
    //MARK: - Propertie
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var likeBtn: UIButton!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var sharedBtn: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    fileprivate var albumList = [AlbumModel]()
    fileprivate var savedImage = UIImage()
    private let bag = DisposeBag()
    var news: NewsModel?                    //接受外界传来的 model

    lazy var failView: UIView = {
        let fail = Bundle.main.loadNibNamed("AlbumFailView", owner: self, options: nil)?.first as! UIView
        return fail
    }()
    
    //MARK: - Properties
    var swipeView: SwipeView!
    var bottomView: UIView!                 //底部的 containerView
    var savedBtn: UIButton!                 //保存按钮
    
    lazy var activityIndicator: UIActivityIndicatorView = {
        let activity = UIActivityIndicatorView(activityIndicatorStyle:UIActivityIndicatorViewStyle.gray)
        activity.center = self.view.center
        self.view.addSubview(activity)
        return activity
    }()

    //MARK: - Method
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.rbg(r: 45, g: 45, b: 45)
        requestList()
        setupSwipeView()

        if let theNews = self.news {
            if let newId = theNews.Id {
                self.checkIfHasCollected(newId)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !(self.navigationController?.isNavigationBarHidden)! {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
        }
    }
    
    @IBAction func likeBtnClick(_ sender: UIButton) {       //处理收藏
        MobClick.event("Auto_PhotoGallery_Like")

        self.likeBtn.isSelected = !self.likeBtn.isSelected
        if UserDataManager.sharedInstance.isLogin {
            
            if let newsId = self.news?.Id {
                if sender.isSelected  {
                    SADataManager.shared().deleteCollectNews(self.news!)    //强解包
                    appAutoApiProvider.rxRequestDelNewsCollection(newsID: newsId).subscribe(onNext: { (response) in
                        guard let jsonDic = response.data as? [String : Any] else {
                            return
                        }
                        
                        self.printLog(jsonDic)
                        
                        }, onError: { (err) in
                            if err is SAError {
                                let saer = err as! SAError
                                if saer.errorResponse?.statusCode == 200 {
                                    self.likeBtn.isSelected = true

                                    HUD.showInWindow(message: "收藏成功", style: .success)
                                }
                            }
                        }, onCompleted: {
                            
                        }, onDisposed: nil).addDisposableTo(bag)
                } else {
                    appAutoApiProvider.rxRequestAddNewsCollection(newsID: newsId).subscribe(onNext: { (response) in
                        guard let jsonDic = response.data as? [String : Any] else {
                            return
                        }
                        
                        self.printLog(jsonDic)
                        
                        }, onError: { (err) in
                            if err is SAError {
                                let saer = err as! SAError
                                if saer.errorResponse?.statusCode == 200 {
                                    HUD.showInWindow(message: "收藏成功", style: .success)
                                    self.likeBtn.isSelected = true
                                }
                            }
                        }, onCompleted: {
                            
                        }, onDisposed: nil).addDisposableTo(bag)
                }
            }
        } else {
            if let news = self.news {
                if sender.isSelected == false {
                    SADataManager.shared().deleteCollectNews(news)
                    HUD.show(in: self.view, message: "已取消收藏", style: .none, dismissTime: 1.2)
                    self.likeBtn.setImage(#imageLiteral(resourceName: "album_collect_w"), for: .normal)

                    self.likeBtn.isSelected = false
                } else {
                    SADataManager.shared().collectNews(news)
                    HUD.show(in: self.view, message: "收藏成功", style: .success, dismissTime: 1.2)
                    self.likeBtn.setImage(#imageLiteral(resourceName: "album_collect_h"), for: .selected)

                    self.likeBtn.isSelected = true
                }
            } else {
                HUD.showInWindow(message: "收藏失败", style: .error)
            }
        }
    }
    
    /// 判断收藏成功与否，并根据情况改变按钮状态
    ///
    /// - parameter newsId:  newsId
    func checkIfHasCollected(_ newsId: String) {
        if UserDataManager.sharedInstance.isLogin {
            appAutoApiProvider.rxRequestHasNewsCollection(newsID: newsId).subscribe(onNext: { (response) in
                guard let jsonDic = response.data as? [String : Any] else {
                    return
                }
                self.printLog(jsonDic)
                
                }, onError: { (err) in
                    if err is SAError {
                        let saer = err as! SAError
                        if saer.errorResponse?.statusCode == 200 {
                            self.likeBtn.isSelected = true
                        } else {
                            self.likeBtn.isSelected = false
                        }
                    }
                }, onCompleted: {
                    
                }, onDisposed: nil).addDisposableTo(bag)
        } else {
            if let news = self.news {
                self.likeBtn.isSelected = SADataManager.shared().hasCollectNews(news)
                self.likeBtn.setImage(#imageLiteral(resourceName: "album_collect_h"), for: .selected)
                self.likeBtn.setImage(#imageLiteral(resourceName: "album_collect_w"), for: .normal)
            }
        }
    }
    
    @IBAction func sharedBtnClick(_ sender: AnyObject) {
        MobClick.event("Auto_PhotoGallery_Share")
        if let theNews = self.news {
            let sharev = ShareView()
            guard let shareImgString = self.news?.image else {
                return
            }
            let shareImageView = UIImageView()
            shareImageView.kf.setImage(with: URL(string: shareImgString))
            
            guard let newsURL = theNews.url , let shareImage = shareImageView.image else {
                return
            }
            
            sharev.show(in: self, url: URL(string: newsURL)!, image: shareImage, title: theNews.title, content: theNews.title, completion: { (state, _, _, err) in
                switch state {
                case .success:
                    HUD.show(in: self.view, message: "分享成功", style: .success, dismissTime: 1.2)
//                case .fail:
//                    HUD.show(in: self.view, message: "分享失败", style: . error, dismissTime: 1.2)
//                case .cancel:
//                    HUD.show(in: self.view, message: "取消分享", style: .none, dismissTime: 1.2)
                default:
                    break
                }
            })
        }
    }
    
    @IBAction func backBtnClick(_ sender: AnyObject) {
        guard let nav = self.navigationController else {
            return
        }
        nav.popViewController(animated: true)
    }
    
    @IBAction func reRequestBtnClick(_ sender: UIButton) {
        requestList()
    }
    
    func requestList() {
        guard let news_id = news?.Id else {
            return
        }
        appAutoApiProvider.rxRequest(target: .albumList(id: news_id),
                                     parameters: nil,
                                     requestClosure: nil)
            .subscribe(onNext: { [unowned self] (response) in
            
            guard let albumArray = response.data as? [Any],
                albumArray.count > 0 else {
                    //提示网络请求失败
                    HUD.show(in: self.view, message: "网络请求失败", style: .error, dismissTime: 1.2)
                    self.setupFailView()
                    return
            }
                
            if let list = Mapper<AlbumModel>().mapArray(JSONArray:albumArray as! [[String : Any]]) {
                self.albumList = list
            }
            self.swipeView.reloadData()
            }, onError: { (error) in
                HUD.show(in: self.view, message: "网络请求失败", style: .error, dismissTime: 1.2)
                self.setupFailView()

            }, onCompleted: {
                self.failView.isHidden = self.albumList.count>0 ? true:false
            }, onDisposed: nil).addDisposableTo(bag)
    }
    
    func setupSwipeView() {
        swipeView = SwipeView.init()
        swipeView.frame = UIScreen.main.bounds
        swipeView.isPagingEnabled = true
        swipeView.delegate = self
        swipeView.dataSource = self
        view.addSubview(swipeView)
        
        bottomView = albumBottomViewFromXib()
        swipeView.addSubview(bottomView)
        
        savedBtn = UIButton.init()
        swipeView.addSubview(savedBtn)
        savedBtn.alpha = 0
        savedBtn.setTitleColor(UIColor.w(), for: .normal)
        savedBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        savedBtn.addTarget(self, action: #selector(saveImageToPhone), for: .touchUpInside)
        savedBtn.setTitle("保存", for: .normal)
        layoutViews()
    }
    
    func setupFailView() {
        swipeView.addSubview(self.failView)
        failView.snp.makeConstraints { (make) in
            make.leading.equalTo(swipeView.snp.leading)
            make.trailing.equalTo(swipeView.snp.trailing)
            make.center.equalTo(swipeView.snp.center)
            make.height.equalTo(400)
        }
    }
    
    func layoutViews() {
        bottomView.snp.makeConstraints { (make) in
            make.leading.equalTo(swipeView.snp.leading)
            make.trailing.equalTo(swipeView.snp.trailing)
            make.bottom.equalTo(swipeView.snp.bottom)
            make.height.equalTo(144)
        }
        
        savedBtn.snp.makeConstraints({ (make) in
            make.right.equalTo(self.view.snp.right).offset(-15)
            make.bottom.equalTo(self.view.snp.bottom).offset(-14)
        })
    }
    
    func albumBottomViewFromXib() -> UIView {        //xib加载底部view
        let bottomView = Bundle.main.loadNibNamed("AlbumBottomView", owner: self, options: nil)?.first as! UIView
        bottomView.alpha = 1.0
        bottomView.backgroundColor = UIColor.clear
        return bottomView
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


//MARK: - SwipeViewDelegate,SwipeViewDataSource
extension AlbumViewController: SwipeViewDelegate,SwipeViewDataSource {
    
    func swipeView(_ swipeView: SwipeView, viewForItemAt index: Int, reusing view: UIView?) -> UIView {
        autoHidden(index: index)
        if let title = albumList[index].desc {
            textView.attributedText = addTextKit(text: title, index: index, count: self.albumList.count)
        } else {
            textView.attributedText = addTextKit(text:(news?.title!)!, index: index, count: self.albumList.count)
        }
        guard let albumViewCell = view as? UIImageView else {
            let albumImageViewCell = AlbumImageView.init(frame:UIScreen.main.bounds)
            
            textView.textColor = UIColor.white
            addImageGesture(imageView:albumImageViewCell)               //增加手势
            if let url = albumList[index].url {
    
                let placeHolder = UIImage.init(named: "album_placeholder")
                albumImageViewCell.kf.setImage(with: URL(string: url), placeholder: placeHolder, options: nil, progressBlock: { (recievedData, totalData) in
                    self.activityIndicator.startAnimating()
                    }, completionHandler: { (image, error, _, imageURL) in
                        self.activityIndicator.stopAnimating()
                        //保存图片
                        if let myImage = image {
                            self.savedImage = myImage
                        }
                })
            } else {
                setupFailView()
            }
            return albumImageViewCell
        }
        
        return albumViewCell
    }
    
    func numberOfItems(in swipeView: SwipeView) -> Int {
        return self.albumList.count
    }
    
    func swipeViewItemSize(_ swipeView: SwipeView) -> CGSize {
        return UIScreen.main.bounds.size
    }
    
    func swipeViewCurrentItemIndexDidChange(_ swipeView: SwipeView) {
        //        slidePageControl.currentPage = swipeView.currentPage
    }
}

//MARK: - other method
extension AlbumViewController {
    
    func addTextKit(text: String,index: Int,count: Int) -> (NSAttributedString) {
        let indexString = "\(index + 1)/\(self.albumList.count)    \(text)"
        
        let attributedString = NSMutableAttributedString(string:indexString)
        attributedString.addAttribute(NSFontAttributeName,
                                      value: UIFont.systemFont(ofSize: 18.0),
                                      range: NSRange(location:0, length:indexString.characters.count))

        attributedString.addAttribute(NSFontAttributeName,
                                      value: UIFont.systemFont(ofSize: 24.0),
                                      range: NSRange(location: 0, length: "\(index + 1)".characters.count))

        attributedString.addAttribute(NSForegroundColorAttributeName, value:UIColor.white, range:NSRange(location:0, length:indexString.characters.count))
        
        return attributedString
        
    }
    
    func autoHidden(index: Int) {
        if index == 0 {
            UIView.animate(withDuration: 0.5, animations: {
                self.bottomView.alpha = 1
                self.savedBtn.alpha = 0
            })
        } else {
            UIView.animate(withDuration: 0.5, animations: {
                self.bottomView.alpha = 0
                self.savedBtn.alpha = 1
            })
        }
    }
    
    func saveImageToPhone() {
        MobClick.event("Auto_PhotoGallery_Save")
        UIImageWriteToSavedPhotosAlbum(self.savedImage, self,#selector(image(image: didFinishSavingWithError: contextInfo: )),nil)
    }
    
    func image(image: UIImage, didFinishSavingWithError: NSError?, contextInfo: AnyObject) {
        if didFinishSavingWithError != nil {
            HUD.show(in: self.view, message: "保存失败", style: .error, dismissTime: 1.2)
            return
        } else {
            HUD.show(in: self.view, message: "保存成功", style: .success, dismissTime: 1.2)
        }
    }
    
    func addImageGesture(imageView: UIImageView) {
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(tapImageView))
        tap.numberOfTapsRequired = 1
        imageView.addGestureRecognizer(tap)
    }
    
    func tapImageView() {
        bottomView.alpha = 1 - bottomView.alpha
        if bottomView.alpha == 1 {
            savedBtn.alpha = 0
        } else {
            UIView.animate(withDuration: 0.5, animations: {
                self.savedBtn.alpha = 1
            })
        }
    }
}


/// 添加图集的类类对象
private class AlbumImageView: UIImageView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.frame = UIScreen.main.bounds
        self.contentMode = .scaleAspectFit
        self.clipsToBounds = true
        self.contentScaleFactor = UIScreen.main.scale
        self.backgroundColor = UIColor.rbg(r: 45, g: 45, b: 45)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
