//
//  MultipartyLayout.swift
//  7.Multiparty-UICollectionView
//
//  Created by Roberto Perez Cubero on 17/04/2017.
//  Copyright © 2017 tokbox. All rights reserved.
//

import UIKit

extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }
}

class MultipartyLayout: UICollectionViewLayout {
    fileprivate var cache = [UICollectionViewLayoutAttributes]()
    fileprivate var cachedNumberOfViews = 0
    
    override func prepare() {
        guard let views = collectionView?.numberOfItems(inSection: 0)
            else {
                cache.removeAll()
                return
        }
        
        if views != cachedNumberOfViews {
            cache.removeAll()
        }
        
        if cache.isEmpty {
            cachedNumberOfViews = views
            let attribs: [UICollectionViewLayoutAttributes] = {
                switch views {
                case 1:
                    return attributesForPublisherFullScreen()
                case 2:
                    return attributesForPublisherAndOneSubscriber()
                case let x where x > 2 && x.isEven:
                    return attributesForAllViewsTwoByTwo(withNumberOfViews: x)
                case let x where x > 2 && !x.isEven:
                    return attributesForPublisherOnTopAndSubscribersTwoByTwo(withNumberOfViews: x)
                default:
                    return []
                }
            }()
            
            cache.append(contentsOf: attribs)
        }
    }
    
    fileprivate func attributesForPublisherFullScreen() -> [UICollectionViewLayoutAttributes] {
        var attribs = [UICollectionViewLayoutAttributes]()
        let ip = IndexPath(item: 0, section: 0)
        let attr = UICollectionViewLayoutAttributes(forCellWith: ip)
        attr.frame = collectionView?.superview?.bounds ?? CGRect()
        attribs.append(attr)
        
        return attribs
    }
    
    // Will layout publisher view over subscriber view
    fileprivate func attributesForPublisherAndOneSubscriber() -> [UICollectionViewLayoutAttributes] {
        var attribs = [UICollectionViewLayoutAttributes]()
        let height = (collectionView?.superview?.bounds.size.height ?? 0) / 2
        let width = collectionView?.superview?.bounds.size.width ?? 0
        
        let pubIp = IndexPath(item: 0, section: 0)
        let pubAttribs = UICollectionViewLayoutAttributes(forCellWith: pubIp)
        pubAttribs.frame = CGRect(x: 0, y: 0, width: width, height: height)
        attribs.append(pubAttribs)
        
        let subIp = IndexPath(item: 1, section: 0)
        let subAttribs = UICollectionViewLayoutAttributes(forCellWith: subIp)
        subAttribs.frame = CGRect(x: 0, y:height, width: width, height: height)
        attribs.append(subAttribs)
        
        return attribs
    }
    
    fileprivate func attributesForPublisherOnTopAndSubscribersTwoByTwo(withNumberOfViews views: Int)
        -> [UICollectionViewLayoutAttributes]
    {
        var attribs = [UICollectionViewLayoutAttributes]()
        let rows = CGFloat(((views  - 1) / 2) + 1)
        let height = (collectionView?.superview?.bounds.size.height ?? 0) / CGFloat(rows)
        let width = (collectionView?.superview?.bounds.size.width ?? 0) / 2
        
        let pubIp = IndexPath(item: 0, section: 0)
        let pubAttribs = UICollectionViewLayoutAttributes(forCellWith: pubIp)
        pubAttribs.frame = CGRect(x: 0, y: 0, width: collectionView?.superview?.bounds.size.width ?? 0, height: height)
        attribs.append(pubAttribs)
        attribs.append(contentsOf: attributesForViewsInRows(initialYOffset: height,
                                                            totalNumberOfViews: views,
                                                            viewSize: CGSize(width: width, height: height),
                                                            viewOffset: 1))
        return attribs
    }
    
    fileprivate func attributesForAllViewsTwoByTwo(withNumberOfViews views: Int)
        -> [UICollectionViewLayoutAttributes]
    {
        var attribs = [UICollectionViewLayoutAttributes]()
        let rows = views / 2
        let height = (collectionView?.superview?.bounds.size.height ?? 0) / CGFloat(rows)
        let width = (collectionView?.superview?.bounds.size.width ?? 0) / 2
        
        attribs.append(contentsOf: attributesForViewsInRows(initialYOffset: 0,
                                                            totalNumberOfViews: views,
                                                            viewSize: CGSize(width: width, height: height),
                                                            viewOffset: 0))
        return attribs
    }
    
    fileprivate func attributesForViewsInRows(initialYOffset: CGFloat,
                                              totalNumberOfViews views: Int,
                                              viewSize: CGSize,
                                              viewOffset: Int)
        -> [UICollectionViewLayoutAttributes]
    {
        var attribs = [UICollectionViewLayoutAttributes]()
        var yOffset = initialYOffset
        
        let newLineCondition : (Int) -> Bool = {
            if viewOffset == 0 {
                return !$0.isEven
            } else {
                return $0.isEven
            }
        }
        
        for item in viewOffset..<views {
            let ip = IndexPath(item: item, section: 0)
            let attrs = UICollectionViewLayoutAttributes(forCellWith: ip)
            let xOffset = CGFloat(newLineCondition(item) ? viewSize.width : 0 )
            attrs.frame = CGRect(x: xOffset, y: yOffset, width: viewSize.width, height: viewSize.height)
            attribs.append(attrs)
            if item > viewOffset && newLineCondition(item) {
                yOffset += viewSize.height
            }
        }
        
        return attribs
    }
    
    override var collectionViewContentSize: CGSize {
        return collectionView?.superview?.bounds.size ?? CGSize()
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache
    }
    
}
