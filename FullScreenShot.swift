//
//  FullScreenShot.swift
//  PASMO
//
//  Created by fjwrer_1004 on 2020/02/19.
//

import UIKit

// MARK: - デバッグ時、モーションジェスチャーでキャプチャを撮影する

#if DEBUG
extension UIViewController {

    open override func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if #available(iOS 13.0, *) {
            self.view.window?.windowScene?.screenshotService?.delegate = self
        } else {
            guard let image = getViewImageRender() else { return }
            if let pngdata = image.pngData() {
                saveData(pngdata)
            }
        }
    }
}
#endif

///フルスクリーンショット可能にするためのクラス
// MARK: - UIScreenshotServiceDelegate

extension UIViewController: UIScreenshotServiceDelegate {

    /// iOS13以降のデリゲート
    /// 使用する場合vcでdelegateを実装する必要がある
    @available(iOS 13.0, *)
    /// スクリーンショット時、フルスクリーンショット可能にする処理
    public func screenshotService(_ screenshotService: UIScreenshotService, generatePDFRepresentationWithCompletion completionHandler: @escaping (Data?, Int, CGRect) -> Void) {

        guard let image = getViewImageRender() else { return }
        guard let pdf = createPDF(image: image) else { return }
        saveData(pdf, type: "pdf")
        completionHandler(pdf, 0, .zero)
    }

    
    // MARK: - 画像の合成

    func getViewImageRender() -> UIImage? {

        var imageArray: [UIImage] = []
        var contentHeight: CGFloat = 0
        var composeImage: UIImage?
        // navigationBarの描画
        guard let navigationController = self.navigationController else { return nil }
        guard let navigationBarImage = getNavigationBarImage(navigationController: navigationController) else { return nil }
        imageArray.append(navigationBarImage)
        contentHeight += navigationBarImage.size.height

        // scrollViewの画像抜き出し
        if let scrollView = self.scrollViewComponent {
            Logger.log("scrollViewの書き出し")
            guard let scrollViewImage = getScrollViewImage(scrollView: scrollView) else { return nil }
            imageArray.append(scrollViewImage)
            contentHeight += scrollViewImage.size.height
            // stackViewの画像抜き出し
        } else if let stackView = self.view.subviews.first as? UIStackView {
            Logger.log("stackViewの書き出し")

            // 子viewの描画
            for component in stackView.subviews {
                if let scrollView = component as? UIScrollView {
                    guard let scrollImage = getScrollViewImage(scrollView: scrollView) else { return nil }
                    imageArray.append(scrollImage)
                    contentHeight += scrollImage.size.height
                } else {
                    guard let image = getViewImage(view: component) else { return nil }
                    imageArray.append(image)
                    contentHeight += image.size.height
                }
            }
        } else {
            // 普通に画面キャプチャを返す
            UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, false, 0.0)
            self.view.window?.layer.render(in: UIGraphicsGetCurrentContext()!)
            let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            return image
        }
        // 合成画像の描画
        UIGraphicsBeginImageContextWithOptions(CGSize(width: self.view.frame.width, height: contentHeight),
                                               false,
                                               0.0)
        var minusHeight: CGFloat = 0
        for (index, image) in imageArray.enumerated() {
            if index == 0 {
                image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                minusHeight += image.size.height
            } else {
                image.draw(in: CGRect(x: 0, y: minusHeight, width: image.size.width, height: image.size.height))
                minusHeight += image.size.height
            }
        }
        composeImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let composedImage = composeImage,
           composedImage.size.height <= self.view.bounds.height {
            // 画面キャプチャを返す
            return getViewImage(view: self.view)
        } else {
            return composeImage
        }

    }

    // MARK: - UIImage書き出し

    /// navigationControllerの書き出し
    private func getNavigationBarImage(navigationController: UINavigationController) -> UIImage? {
        Logger.log("NavigationBarImage")
        //コンテキスト開始
        UIGraphicsBeginImageContextWithOptions(navigationController.navigationBar.frame.size, false, 0.0)
        // navigationBarの描画
        navigationController.navigationBar.drawHierarchy(in: .init(origin: .zero, size: navigationController.navigationBar.frame.size), afterScreenUpdates: true)
        // imageにコンテキストの内容を書き出す
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        //コンテキストを閉じる
        UIGraphicsEndImageContext()
        return image
    }

    /// 汎用的なViewの書き出し
    private func getViewImage(view: UIView) -> UIImage? {
        Logger.log("ViewImage")
        //コンテキスト開始
        UIGraphicsBeginImageContextWithOptions(view.frame.size, false, 0.0)
        //viewを書き出す
        view.drawHierarchy(in: .init(origin: .zero, size: view.frame.size), afterScreenUpdates: true)
        // imageにコンテキストの内容を書き出す
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        //コンテキストを閉じる
        UIGraphicsEndImageContext()
        return image
    }

    /// 汎用的なscrollViewの書き出し
    private func getScrollViewImage(scrollView: UIScrollView) -> UIImage? {
        Logger.log("scrollViewImage")

        // 元のサイズ
        let originalContentOffset = scrollView.contentOffset
        let originalContentInset = scrollView.contentInset
        let originalTableViewBgColor = scrollView.backgroundColor

        let contentHeight = scrollView.contentSize.height
            + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom

        scrollView.contentOffset = .zero
        scrollView.contentInset = .zero
        scrollView.backgroundColor = .systemGroupedBackground

        UIGraphicsBeginImageContextWithOptions(.init(width: scrollView.contentSize.width, height: contentHeight), false, 0)
        // 全てのコンテンツが表示されるのに必要なスクロール回数を計算する
        let numberOfScrolls = ceil(scrollView.contentSize.height / scrollView.frame.size.height)
        (0..<Int(numberOfScrolls)).forEach {
            if $0 == 0 {
                // scrollView（１枚目）の描画
                scrollView.contentOffset.y = 0
                // navigationBar分下から描画
                scrollView.drawHierarchy(in: .init(origin: .init(x: 0, y: 0),
                                                   size: scrollView.frame.size), afterScreenUpdates: true)
            } else {
                let y = scrollView.frame.height * CGFloat($0)
                scrollView.contentOffset.y = scrollView.frame.height * CGFloat($0)
                scrollView.drawHierarchy(in: .init(origin: .init(x: 0, y: y), size: scrollView.frame.size), afterScreenUpdates: true)
            }
        }

        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!

        // 最後元の値に戻す
        defer {
            UIGraphicsEndImageContext()
            scrollView.contentInset = originalContentInset
            scrollView.contentOffset = originalContentOffset
            scrollView.backgroundColor = originalTableViewBgColor
        }
        return image
    }

    // MARK: - tmpファイルに保存

    /// 画像をtmpディレクトリに保存する
    /// 指定なしの場合:png保存
    private func saveData(_ data: Data, type: String = "png") {
        // 保存先
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMddHHmmss"
        let filePath = "\(NSTemporaryDirectory())\(fmt.string(from: Date()))ScreenShot.\(type)"
        do {
            Logger.log("スクリーンショット保存：\(filePath)")
            try data.write(to: URL(fileURLWithPath: filePath))
        } catch {
            Logger.log("スクショ保存失敗")
            return
        }
    }

    private func createPDF(image: UIImage) -> Data? {
        let imageView = UIImageView(image: image)
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, .init(x: 0, y: 0, width: image.size.width, height: image.size.height), nil)
        UIGraphicsBeginPDFPage()
        guard let pdfContext = UIGraphicsGetCurrentContext() else { return nil }
        imageView.layer.render(in: pdfContext)
        UIGraphicsEndPDFContext()
        let data = pdfData as Data
        return data

    }

}

// MARK: - return scrollViewComponent

extension UIViewController {

    /// scrollViewを返却
    var scrollViewComponent: UIScrollView? {
        guard let scrollViewComponent = scrollViewComponent(base: self) else {
            return nil
        }
        return scrollViewComponent
    }

    /// scrollViewを検索して返却
    func scrollViewComponent(base: UIViewController? = UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.rootViewController) -> UIScrollView? {

        if let vc = base as? UITableViewController {
            return vc.tableView
        } else {
            if let vcViews = base?.view.subviews {
                for component in vcViews {
                    Logger.log("scrollViewComponent: \(type(of: component))")
                    if let scrollView = component as? UIScrollView {
                        return scrollView
                    }
                }
            }
        }
        return nil
    }
}
