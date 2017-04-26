Multiparty UICollectionView Sample App
========================================

If you plan to build a multiparty app, you may want to use `UICollectionView` to dynamically
adapt to the screen size and display the video views of all participants in an OpenTok session.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

Use `UICollectionView` to easily specify the way views are displayed.

## Creating a custom layout for UICollectionView

When building custom layouts, you need to subclass `UICollectionViewLayout` and override two
methods (`prepare()` and `layoutAttributesForElements(in:)`) and a computed property
(`collectionViewContentSize`).

First, you need to return the size of the entire `UICollectionView`. In our case, since we want
to fill the entire screen without scrolling, we simply return the size of the `UICollectionView`
container by overriding `collectionViewContentSize()`:

```swift
override var collectionViewContentSize: CGSize {
    return collectionView?.superview?.bounds.size ?? CGSize()
}
```

When the view is going to be laid out, `UIKit` calls the implementation of the
`MultipartyLayout.prepare()` method. This method prepares values used when the views are drawn.
It populates a cache, which is a `UICollectionViewLayoutAttributes` object that specifies the size
and position of each item:

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

The implementation of the `UICollectionViewLayout.layoutAttributesForElements(in:)` method is
called when the views are laid out. It returns the cache containing the actual view sizes:

```swift
override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    return cache
}
```
