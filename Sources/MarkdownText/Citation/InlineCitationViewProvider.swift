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
    // Size the pill ourselves in `attachmentBounds`. On the TextKit2 path
    // (UITextView on iOS 26) the view's own bounds would otherwise drive the line
    // fragment height; the citation view is taller than the body text's cap box,
    // so it would push this line taller than its neighbors.
    tracksTextAttachmentViewBounds = false
  }

  /// Constrain the pill to the surrounding text's own vertical box: cap the
  /// height to the body cap height and sit it from the baseline up to the cap
  /// (the same box the digits occupy). It then contributes no more ascent — and
  /// no descent — than the text on that line, so the line height never changes.
  /// (Paired with the removal of the attachment's `.baselineOffset` in
  /// `Paragraph+.swift`, which was inflating the paragraph's measured height.)
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
    let height = min(natural.height, font.capHeight)
    return CGRect(x: 0, y: 0, width: natural.width, height: height)
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
