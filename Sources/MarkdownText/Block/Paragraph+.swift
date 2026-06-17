//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Markdown
import SwiftUI

extension Paragraph: BlockConvertible {

  func convert(attributeContainer: NSAttributeContainer, config: MarkdownRenderConfig) -> MarkdownRenderable {
    var container = attributeContainer
    container[.font] = config.paragraphStyle.textFonts.normal
    container[.typography] = config.paragraphStyle.textFonts
    if let kern = config.paragraphStyle.textFonts.preferredLetterSpacing {
      container[.kern] = kern
    }
    container[.foregroundColor] = config.paragraphStyle.textColor
    let paragraphContent: NSMutableAttributedString = self.buildParagraphContent(container: container, config: config)
    return MarkdownRenderable.paragraph(id: self.id, content: paragraphContent)
  }
}

extension BlockMarkup {

  func buildParagraphContent(container: NSAttributeContainer, config: MarkdownRenderConfig) -> NSMutableAttributedString {
    let result = NSMutableAttributedString()

    for child in self.children {
      guard let convertible = child as? InlineConvertible else {
        continue
      }

      let coder = config.citationConfig.coder
      if config.citationConfig.isEnabled,
         let link = child as? Markdown.Link,
         let destination = link.destination,
         link.isInlineCitation(coder: coder) {

        // Create citation attachment directly during parsing (as suggested by @hanzhouli_microsoft)
        let attachmentData = coder.decode(linkDestination: destination)
        if let attachmentData = attachmentData,
           let attachment = InlineCitationAttachment(citationData: attachmentData, citationConfig: config.citationConfig) {
          let attachmentString = NSMutableAttributedString(attachment: attachment)
          let fullRange = NSRange(location: 0, length: attachmentString.length)

          // Give the attachment character the surrounding paragraph font so the
          // line-height clamp (ParagraphUIView.setCSSLineHeight) and layout see a
          // normal run, not a metric-less attachment glyph.
          attachmentString.addAttribute(
            .font,
            value: config.paragraphStyle.textFonts.normal,
            range: fullRange
          )
          // Add link attribute for accessibility activation (space key)
          attachmentString.addAttribute(.link, value: attachmentData.url, range: fullRange)

          // NOTE: do NOT apply a negative `.baselineOffset` (= font descender) to
          // the attachment character. It leaves each line fragment at the clamped
          // height but inflates the paragraph's measured/`sizeThatFits` height, so a
          // paragraph containing a citation reads ~descender-pt taller than its
          // neighbors even though the pill itself fits. (Audited 2026-06-17.)

          // Add the citation directly to result
          result.append(attachmentString)
        }
      } else {
        let stringPart = convertible.convert(attributeContainer: container, config: config)
        result.append(stringPart)
      }
    }

    return result
  }
}
