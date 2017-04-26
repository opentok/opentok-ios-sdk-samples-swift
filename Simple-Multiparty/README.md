Simple Multiparty Sample App
==============================

Previous samples subscribe to only one stream. In a multiparty video audio call
there should be multiple parties.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

This simple multiparty app is able to handle only four subscriber parties. On a
new stream received the ViewController class creates a new Subscriber object and
subscribes the Session object to it. The Subscriber stream is rendered in the
screen as we did it before.

This sample uses a UICollectionView to show each subscriber view. We use a custom
UICollectionViewCell that will hold the subscriber view and will also control some
basic user interface to mute the audio of that subscriber.

```swift
class SubscriberCollectionCell: UICollectionViewCell {
  @IBOutlet var muteButton: UIButton!

  var subscriber: OTSubscriber?

  @IBAction func muteSubscriberAction(_ sender: AnyObject) {
    subscriber?.subscribeToAudio = !(subscriber?.subscribeToAudio ?? true)

    let buttonImage: UIImage  = {
      if !(subscriber?.subscribeToAudio ?? true) {
        return #imageLiteral(resourceName: "Subscriber-Speaker-Mute-35")
      } else {
        return #imageLiteral(resourceName: "Subscriber-Speaker-35")
      }
    }()

    muteButton.setImage(buttonImage, for: .normal)
  }

  override func layoutSubviews() {
    if let sub = subscriber {
      sub.view.frame = bounds
      contentView.insertSubview(sub.view, belowSubview: muteButton)

      muteButton.isEnabled = true
      muteButton.isHidden = false
    }
  }
}
```

## Adding user interface controls

The ViewController class shows how you can add user interface controls for the following:

* Turning a publisher's audio stream on and off
* Swapping the publisher's camera

When the user taps the mute button for the publisher, the following method of the ViewController 
class is invoked:

```swift
@IBAction func muteMicAction(_ sender: AnyObject) {
  publisher.publishAudio = !publisher.publishAudio
  let buttonImage: UIImage  = {
    if !publisher.publishAudio {
      return #imageLiteral(resourceName: "mic_muted-24")
    } else {
      return #imageLiteral(resourceName: "mic-24")
    }
    }()
                                                                                                      
    muteMicButton.setImage(buttonImage, for: .normal)
}
```

## Next steps

For details on the full OpenTok Android API, see the [reference
documentation](https://tokbox.com/developer/sdks/ios/reference/index.html).
