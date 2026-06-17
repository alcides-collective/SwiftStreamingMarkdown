//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI
import UIKit

private final class AttachmentCitationLabel: UILabel {
  private let textInsets = InlineCitationAttachment.textInsets

  // MARK: Initialization

  init(
    title: String,
    font: UIFont,
    textColor: UIColor,
    backgroundColor: UIColor
  ) {
    super.init(frame: .zero)
    self.backgroundColor = backgroundColor
    self.layer.cornerRadius = InlineCitationAttachment.cornerRadius
    self.layer.masksToBounds = true
    self.font = font
    self.textColor = textColor
    self.textAlignment = .center
    self.numberOfLines = 1
    self.text = title

    // This prevents inline citations from being focusable in linear VoiceOver navigation
    // Citations will still be accessible via the Links rotor through the parent UITextView
    self.isAccessibilityElement = false
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: Layout

  override func drawText(in rect: CGRect) {
    let insetRect = rect.inset(by: textInsets)
    super.drawText(in: insetRect)
  }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + textInsets.left + textInsets.right,
      height: size.height + textInsets.top + textInsets.bottom
    )
  }
}

final class InlineCitationViewProvider: NSTextAttachmentViewProvider {
  required override init(
    textAttachment attachment: NSTextAttachment,
    parentView: UIView?,
    textLayoutManager: NSTextLayoutManager?,
    location: any NSTextLocation
  ) {
    super.init(
      textAttachment: attachment,
      parentView: parentView,
      textLayoutManager: textLayoutManager,
      location: location
    )
    // We size the pill ourselves in `attachmentBounds` so it never grows the
    // surrounding line height; don't let the view's own (taller) bounds drive it.
    tracksTextAttachmentViewBounds = false
  }

  /// Keep the citation pill within its line. The pill's natural height (its
  /// font's full line height + vertical insets) is taller than the body text's
  /// cap height, so with the view's own bounds it would force this line taller
  /// than its neighbors — and an inline attachment overrides `maximumLineHeight`.
  /// Cap the height to the surrounding text's cap height (+ a little breathing
  /// room) and center it on the text's cap midline so it raises neither the
  /// line's ascent nor its descent.
  override func attachmentBounds(
    for attributes: [NSAttributedString.Key: Any],
    location: any NSTextLocation,
    textContainer: NSTextContainer?,
    proposedLineFragment: CGRect,
    position: CGPoint
  ) -> CGRect {
    guard let label = view else { return .zero }
    let natural = label.intrinsicContentSize
    let font = (attributes[.font] as? UIFont) ?? UIFont.preferredFont(forTextStyle: .body)
    let height = min(natural.height, font.capHeight + 5)
    let y = font.capHeight / 2 - height / 2
    return CGRect(x: 0, y: y, width: natural.width, height: height)
  }

  override func loadView() {
    // Use the pre-decoded data from InlineCitationAttachment for optimal performance
    // (avoids redundant JSON parsing on every loadView call)
    guard let attachment = textAttachment as? InlineCitationAttachment,
          let data = attachment.citationData else {
      return
    }

    self.view = AttachmentCitationLabel(
      title: data.title,
      font: attachment.font,
      textColor: attachment.textColor,
      backgroundColor: attachment.backgroundColor
    )
  }
}
