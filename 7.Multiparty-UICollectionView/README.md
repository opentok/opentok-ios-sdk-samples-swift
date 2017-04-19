# Project 7: Multiparty App Using UICollectionView

If you plan to build a multiparty, social-like app you will probably want to use `UICollectionView` to layout the different views of the participants.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md/quick-start) section of the main README file
for this repository.

The reason of using UICollectionView is because it allows to easily specify the way the views are displayed.

This sample uses a custom layout to dynamically adapt the screen size to display all participants.

## Creating a custom layout for UICollectionView

When building custom layouts, you need to subclass `UICollectionViewLayout` and override two methods and a computed property.

First, you need to return how big the whole `UICollectionView` is. In our case, since we want to just cover the whole screen without the need of having any scroll, we would just return the size of the `UICollectionView` container. We do that by overriding `collectionViewContentSize`:

```swift
override var collectionViewContentSize: CGSize {
    return collectionView?.superview?.bounds.size ?? CGSize()
}
```

When the view is going to be layed out, `UIKit` will call `prepare` function of our subclass. Here we should do the preparations for the values we will return when the views are being actually drawed. It is recommended to use a cache which will be populated in this method, so in the next method we will just return the contents of the cache. The content of the cache are `UICollectionViewLayoutAttributes` which specified the size and position of each item.

```swift
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
```

Lastly, we need to return the actual view sizes in the method which is called when the views are layed out in the view. We will do that in `layoutAttributesForElements`
function.

```swift
override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    return cache
}
```
