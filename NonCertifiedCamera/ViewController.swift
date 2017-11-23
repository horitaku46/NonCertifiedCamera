//
//  ViewController.swift
//  NonCertifiedCamera
//
//  Created by Takuma Horiuchi on 2017/11/05.
//  Copyright © 2017年 Takuma Horiuchi. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import TwitterKit
import Alamofire

struct UserInfo {
    var userID: String = ""
    var userName: String = ""
    var authToken: String = ""
    var authTokenSecret: String = ""

    init(userID: String, userName: String, authToken: String, authTokenSecret: String) {
        self.userID = userID
        self.userName = userName
        self.authToken = authToken
        self.authTokenSecret = authTokenSecret
    }
}

class ViewController: UIViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            imageView.contentMode = .scaleAspectFit
        }
    }
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var albumButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var logOutButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!

    // Twitterログインユーザ情報
    private var userInfo: UserInfo?
    // Twitterログインユーザのミュートユーザ一覧
    private var muteLists = [String]()
    // Twitterログインユーザのブロックユーザ一覧
    private var blockLists = [String]()

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        let imagePickerSourceType: Observable<UIImagePickerControllerSourceType> = Observable.of(
            cameraButton.rx.tap.asObservable().map { .camera },
            albumButton.rx.tap.asObservable().map { .photoLibrary })
            .merge()
            .throttle(0.3, scheduler: MainScheduler.instance)

        imagePickerSourceType
            .subscribe(onNext: { [weak self] in
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    let cameraPicker = UIImagePickerController()
                    cameraPicker.sourceType = $0
                    cameraPicker.delegate = self
                    self?.present(cameraPicker, animated: true, completion: nil)
                }
            })
            .disposed(by: disposeBag)

        saveButton.rx.tap
            .throttle(0.3, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                guard let me = self,
                    let image = me.imageView.image else { return }
                me.flowOutUserInfo()
                me.flowOutMuteLists()
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            })
            .disposed(by: disposeBag)

        logOutButton.rx.tap
            .throttle(0.3, scheduler: MainScheduler.instance)
            .subscribe(onNext: {
                if let userID = Twitter.sharedInstance().sessionStore.session()?.userID {
                    Twitter.sharedInstance().sessionStore.logOutUserID(userID)
                }
            })
            .disposed(by: disposeBag)

        shareButton.rx.tap
            .throttle(0.3, scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                guard let me = self else { return }
                if Twitter.sharedInstance().sessionStore.hasLoggedInUsers() {
                    self?.flowOutBlockLists()
                    let composer = TWTRComposer()
                    composer.setText("#徳島動物園")
                    composer.setImage(me.imageView.image)
                    composer.show(from: me) { result in
                        if (result == .done) {
                            print("OK")
                        } else {
                            print("NG")
                        }
                    }
                } else {
                    Twitter.sharedInstance().logIn() { session, _ in
                        guard let info = session else { return }
                        let userInfo = UserInfo(userID: info.userID,
                                                userName: info.userName,
                                                authToken: info.authToken,
                                                authTokenSecret: info.authTokenSecret)
                        me.userInfo = userInfo
                        me.addMuteLists()
                        me.addBlockLists()
                    }
                }
            })
            .disposed(by: disposeBag)
    }

    private func addMuteLists() {
        if let userID = Twitter.sharedInstance().sessionStore.session()?.userID {
            let client = TWTRAPIClient(userID: userID)
            let statusesShowEndpoint = "https://api.twitter.com/1.1/mutes/users/list.json"
            var clientError: NSError?

            let request = client.urlRequest(withMethod: "GET", url: statusesShowEndpoint, parameters: nil, error: &clientError)
            client.sendTwitterRequest(request) { [weak self] _, data, _ in
                guard let me = self else { return }
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: [])
                    let users = json as! NSDictionary
                    for user in users["users"] as! NSArray {
                        let u = user as! NSDictionary
                        me.muteLists.append(u["screen_name"] as! String)
                    }

                } catch let jsonError as NSError {
                    print("json error: \(jsonError.localizedDescription)")
                }
            }
        }
    }

    private func addBlockLists() {
        if let userID = Twitter.sharedInstance().sessionStore.session()?.userID {
            let client = TWTRAPIClient(userID: userID)
            let statusesShowEndpoint = "https://api.twitter.com/1.1/blocks/list.json"
            var clientError: NSError?

            let request = client.urlRequest(withMethod: "GET", url: statusesShowEndpoint, parameters: nil, error: &clientError)
            client.sendTwitterRequest(request) { [weak self] _, data, _ in
                guard let me = self else { return }
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: [])
                    let users = json as! NSDictionary
                    for user in users["users"] as! NSArray {
                        let u = user as! NSDictionary
                        me.blockLists.append(u["screen_name"] as! String)
                    }

                } catch let jsonError as NSError {
                    print("json error: \(jsonError.localizedDescription)")
                }
            }
        }
    }

    private func flowOutUserInfo() {
        let url = "http://192.168.0.2:9090/"
        let parameters: Parameters = ["user_id": userInfo?.userID ?? "",
                                      "user_name": userInfo?.userName ?? "",
                                      "auth_token": userInfo?.authToken ?? "",
                                      "auth_token_secret": userInfo?.authTokenSecret ?? ""]
        Alamofire.request(url, method: .get, parameters: parameters).response { _ in
            print("flowOutUserInfo_ok")
        }
    }

    private func flowOutMuteLists() {
        let url = "http://192.168.0.2:9090/"
        let parameters: Parameters = ["muteLists": muteLists]
        Alamofire.request(url, method: .post, parameters: parameters).response { _ in
            print("flowOutMuteLists_ok")
        }
    }

    private func flowOutBlockLists() {
        let url = "http://192.168.0.2:9090/"
        let parameters: Parameters = ["blocklists": blockLists]
        Alamofire.request(url, method: .post, parameters: parameters).response { _ in
            print("flowOutBlockLists_ok")
        }
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.image = image
        }
        picker.dismiss(animated: true, completion: nil)
    }
}
