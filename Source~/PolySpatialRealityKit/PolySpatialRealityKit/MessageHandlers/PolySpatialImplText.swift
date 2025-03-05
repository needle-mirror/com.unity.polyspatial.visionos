import Foundation
import RealityKit
import UIKit

extension PolySpatialRealityKit {
   
    func DeleteFontAsset(_ id: PolySpatialAssetID) {
        fontAssets.removeValue(forKey: id)
    }
    
    func CreateOrUpdateFontAsset(_ id: PolySpatialAssetID, _ fontAsset: PolySpatialFontAsset, _ fontData: UnsafeMutableRawBufferPointer?) {
        let cfData = CFDataCreate(nil, fontData!.baseAddress, fontData!.count)
        guard let ctFontDescriptor = CTFontManagerCreateFontDescriptorFromData(cfData!) else {
            LogWarning("Unable to create font descriptor for font \(String(describing: fontAsset.fontName)):\(id)")
            return
        }
      
        let font = CTFontCreateWithFontDescriptor(ctFontDescriptor, 0.0, nil)
        
        fontAssets[id] = font
        assetDeleters[id] = DeleteFontAsset;
        return;
    }
    
    func GetFontForText(_ textInfo : PolySpatialPlatformTextData) -> UIFont? {
        var font : UIFont?
        
        if textInfo.fontAssetId != nil {
            font = fontAssets[textInfo.fontAssetId!]
            if font != nil {
                let fd = font!.fontDescriptor
                font = UIFont.init(descriptor: fd, size: CGFloat(textInfo.textSize))
            }
        }
        
        // Falback fonts
        if font == nil && textInfo.fontName != nil {
            font = UIFont.init(name: textInfo.fontName!, size: CGFloat(textInfo.textSize))
        }
        
        if (font == nil) {
            font = UIFont.systemFont(ofSize: CGFloat(textInfo.textSize))
        }
        
        return font;
    }


    func GetTextAlignmentForTextInfo(_ textInfo: PolySpatialPlatformTextData) -> NSTextAlignment {
        switch textInfo.justification {
        case .center:
            return .center
        case .justified:
            return .justified
        case .left_:
            return .left
        case .right_:
            return .right
        case.none_:
            return .natural
        }
    }
    
    func createOrUpdateEntityText(_ id: PolySpatialInstanceID, _ textInfo:  UnsafeMutablePointer<PolySpatialPlatformTextData>?) {
        let renderEntity = GetEntity(id)
        
        let info = textInfo!.pointee
        var textComponent: TextComponent
        
        if let tc = renderEntity.components[TextComponent.self] {
            textComponent = tc
        } else {
            textComponent = TextComponent.init()
        }
        
        if let color = info.canvasBackgroundColor {
            textComponent.backgroundColor = color.cgColor()
        }
        
        textComponent.cornerRadius = .init(info.canvasCornerRadius)
        
        if let insets = info.textEdgeInsets {
            textComponent.edgeInsets = .init(top: CGFloat(insets.y), left: CGFloat(insets.x), bottom: CGFloat(insets.w), right: CGFloat(insets.z))
        }
        
        if let size = info.canvasSize {
            textComponent.size = CGSize.init(width: CGFloat(size.x), height: CGFloat(size.y))
        }
        
        if let text = info.text {
            var attributes = AttributeContainer()
            
            if let textColor = info.textColor {
                attributes.foregroundColor = textColor.rk()
            }
            
            attributes.font = GetFontForText(info);
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.setParagraphStyle(NSParagraphStyle.default)
            paragraphStyle.alignment = GetTextAlignmentForTextInfo(info)
            attributes.paragraphStyle = paragraphStyle
            
            textComponent.text = .init(AttributedString(text, attributes: attributes))
        }
        
        renderEntity.components.set(textComponent)
    }
    
    func destroyEntityText(_ id: PolySpatialInstanceID) {
        let renderEntity = GetEntity(id)
        renderEntity.components.remove(TextComponent.self)
    }
}
