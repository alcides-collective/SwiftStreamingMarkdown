//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI
import UIKit

/// Inline citation chip that NEVER grows its line.
///
/// The container claims only a small vertical box (`claimedHeight`, ~the chip
/// font's cap height) for text layout, so the line fragment height stays equal to
/// the surrounding body text. The actual rounded pill is drawn at its full
/// natural size, vertically centered on that small box with clipping off, so it
/// overflows above/below and may slightly cover adjacent lines — an accepted
/// tradeoff for perfectly uniform line height. Driven via the view's
/// `intrinsicContentSize` with `tracksTextAttachmentViewBounds = true` (the path
/// that actually governs line height for view-provider attachments here).
private final class AttachmentCitationLabel: UIView {
  private let textInsets = InlineCitationAttachment.textInsets
  private let pill = UILabel()
  /// Full natural size of the visible chip (text + insets).
  private let pillSize: CGSize
  /// The height claimed for text layout. Kept at the chip font's cap height,
  /// which is below the body text's ascent, so the line never grows.
  private let claimedHeight: CGFloat

  init(
    title: String,
    font: UIFont,
    textColor: UIColor,
    backgroundColor: UIColor
  ) {
    let textSize = (title as NSString).size(withAttributes: [.font: font])
    pillSize = CGSize(
      width: ceil(textSize.width) + textInsets.left + textInsets.right,
      height: ceil(textSize.height) + textInsets.top + textInsets.bottom
    )
    claimedHeight = ceil(font.capHeight)

    super.init(frame: .zero)

    // Let the pill overflow this container's (small) box onto adjacent lines.
    clipsToBounds = false
    // Touches fall through to the parent UITextView, which handles the citation
    // link/attachment tap; keep the chip out of linear VoiceOver (it's reachable
    // via the Links rotor).
    isUserInteractionEnabled = false
    isAccessibilityElement = false

    pill.backgroundColor = backgroundColor
    pill.layer.cornerRadius = InlineCitationAttachment.cornerRadius
    pill.layer.masksToBounds = true
    pill.font = font
    pill.textColor = textColor
    pill.textAlignment = .center
    pill.numberOfLines = 1
    pill.text = title
    pill.isAccessibilityElement = false
    addSubview(pill)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: CGSize {
    // Full width (so following text doesn't overlap the chip horizontally) but
    // only a small claimed height (so the line height matches body text).
    CGSize(width: pillSize.width, height: claimedHeight)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // Center the full-size chip on the claimed box; it overflows symmetrically.
    pill.frame = CGRect(
      x: 0,
      y: (bounds.height - pillSize.height) / 2.0,
      width: pillSize.width,
      height: pillSize.height
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
    // Track the view's bounds: the container reports a small `intrinsicContentSize`
    // height, so the attachment occupies little vertical space and the line height
    // stays equal to the body text. The chip itself overflows that box.
    tracksTextAttachmentViewBounds = true
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
