//
//  YPPhotoFiltersVC.swift
//  photoTaking
//
//  Created by Sacha Durand Saint Omer on 21/10/16.
//  Copyright © 2016 octopepper. All rights reserved.
//

import UIKit

protocol IsMediaFilterVC: class {
    var didSave: ((YPMediaItem) -> Void)? { get set }
    var didCancel: (() -> Void)? { get set }
}

open class YPPhotoFiltersVC: UIViewController, IsMediaFilterVC {
    
    override open var prefersStatusBarHidden: Bool { return YPConfig.hidesStatusBar }
    
    var v = YPFiltersView()
    
    var filterPreviews = [YPFilterPreview]()
    var filters = [YPFilter]()
    
    var inputPhoto: YPPhoto!
    var thumbImage = UIImage()
    
    var isImageFiltered = false
    private var isFromSelectionVC = false
    
    var didSave: ((YPMediaItem) -> Void)?
    var didCancel: (() -> Void)?
    
    override open func loadView() { view = v }
    
    required public init(inputPhoto: YPPhoto, isFromSelectionVC: Bool) {
        super.init(nibName: nil, bundle: nil)
        
        self.inputPhoto = inputPhoto
        self.isFromSelectionVC = isFromSelectionVC
        
        for filterDescriptor in YPConfig.filters {
            filterPreviews.append(YPFilterPreview(filterDescriptor.name))
            filters.append(YPFilter(filterDescriptor.filterName))
        }
    }
    
    func thumbFromImage(_ img: UIImage) -> UIImage {
        let width: CGFloat = img.size.width / 5
        let height: CGFloat = img.size.height / 5
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        img.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let smallImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return smallImage!
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        v.imageView.image = inputPhoto.image
        thumbImage = thumbFromImage(inputPhoto.image)
        v.collectionView.register(YPFilterCollectionViewCell.self, forCellWithReuseIdentifier: "FilterCell")
        v.collectionView.dataSource = self
        v.collectionView.delegate = self
        v.collectionView.selectItem(at: IndexPath(row: 0, section: 0),
                                                  animated: false,
                                                  scrollPosition: UICollectionViewScrollPosition.bottom)
        
        // Navigation bar setup
        title = YPConfig.wordings.filter
        navigationController?.navigationBar.tintColor = YPConfig.colors.navigationBarTextColor
        if isFromSelectionVC {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: YPConfig.wordings.cancel,
                                                                style: .plain,
                                                                target: self,
                                                                action: #selector(cancel))
        }
        let rightBarButtonTitle = isFromSelectionVC ? YPConfig.wordings.save : YPConfig.wordings.next
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: rightBarButtonTitle,
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(save))
        YPHelper.changeBackButtonIcon(self)
        YPHelper.changeBackButtonTitle(self)
    }
    
    @objc
    func cancel() {
        didCancel?()
    }
    
    @objc
    func save() {
        let outputImage = v.imageView.image!

        if isImageFiltered && YPConfig.shouldSaveNewPicturesToAlbum {
            YPPhotoSaver.trySaveImage(outputImage, inAlbumNamed: YPConfig.albumName)
        }
        let photo = YPPhoto(image: v.imageView.image!)
        didSave?(YPMediaItem.photo(p: photo))
    }
}

extension YPPhotoFiltersVC: UICollectionViewDataSource {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filterPreviews.count
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let filterPreview = filterPreviews[indexPath.row]
        if let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FilterCell",
                                                         for: indexPath) as? YPFilterCollectionViewCell {
            cell.name.text = filterPreview.name
            if let img = filterPreview.image {
                cell.imageView.image = img
            } else {
                let filter = self.filters[indexPath.row]
                let filteredImage = filter.filter(self.thumbImage)
                cell.imageView.image = filteredImage
                filterPreview.image = filteredImage // Cache
            }
            return cell
        }
        return UICollectionViewCell()
    }
}

extension YPPhotoFiltersVC: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedFilter = filters[indexPath.row]
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            let filteredImage = selectedFilter.filter(self.inputPhoto.image)
            DispatchQueue.main.async {
                self.v.imageView.image = filteredImage
            }
        }
        
        self.isImageFiltered = selectedFilter.name != ""
    }
}