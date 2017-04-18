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
        get {
            return self % 2 == 0
        }
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
            if views == 1 {
                // The pub is alone, lay it full screen
                let ip = IndexPath(item: 0, section: 0)
                let attribs = UICollectionViewLayoutAttributes(forCellWith: ip)
                attribs.frame = collectionView!.superview!.bounds
                cache.append(attribs)
            } else if views == 2 {
                let height = collectionView!.superview!.bounds.size.height / 2
                let width = collectionView!.superview!.bounds.size.width
                
                // Lay out one view over the other
                let pubIp = IndexPath(item: 0, section: 0)
                let pubAttribs = UICollectionViewLayoutAttributes(forCellWith: pubIp)
                pubAttribs.frame = CGRect(x: 0, y: 0, width: width, height: height)
                cache.append(pubAttribs)
                
                let subIp = IndexPath(item: 1, section: 0)
                let subAttribs = UICollectionViewLayoutAttributes(forCellWith: subIp)
                subAttribs.frame = CGRect(x: 0, y:height, width: width, height: height)
                cache.append(subAttribs)
            } else {
                if views.isEven {
                    let rows = views / 2
                    let height = collectionView!.superview!.bounds.size.height / CGFloat(rows)
                    let width = collectionView!.superview!.bounds.size.width / 2
                    // Make two columns keeping the publisher in the top left
                    var yOffset = CGFloat(0)
                    for item in 0..<views {
                        let ip = IndexPath(item: item, section: 0)
                        let attribs = UICollectionViewLayoutAttributes(forCellWith: ip)
                        let xOffset = CGFloat(item.isEven ? 0 : width)
                        attribs.frame = CGRect(x: xOffset, y: yOffset, width: width, height: height)
                        cache.append(attribs)
                        if item > 0 && !item.isEven {
                            yOffset += height
                        }
                    }
                } else {
                    let rows = CGFloat(((views  - 1) / 2) + 1)
                    let height = collectionView!.superview!.bounds.size.height / CGFloat(rows)
                    let width = collectionView!.superview!.bounds.size.width / 2
                    
                    let pubIp = IndexPath(item: 0, section: 0)
                    let pubAttribs = UICollectionViewLayoutAttributes(forCellWith: pubIp)
                    pubAttribs.frame = CGRect(x: 0, y: 0, width: collectionView!.superview!.bounds.size.width, height: height)
                    cache.append(pubAttribs)
                    
                    var yOffset = CGFloat(height)
                    for item in 1..<views {
                        let ip = IndexPath(item: item, section: 0)
                        let attribs = UICollectionViewLayoutAttributes(forCellWith: ip)
                        let xOffset = CGFloat(!item.isEven ? 0 : width)
                        attribs.frame = CGRect(x: xOffset, y: yOffset, width: width, height: height)
                        cache.append(attribs)
                        if item != 1 && item.isEven {
                            yOffset += height
                        }
                    }
                }
            }
        }
        
    }
    
    override var collectionViewContentSize: CGSize {
        get {
            return collectionView!.superview!.bounds.size
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache
    }
    
}
