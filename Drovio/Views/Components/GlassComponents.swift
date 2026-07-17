//
//  GlassComponents.swift
//  Drovio
//
//  Custom styling for the liquid glass aesthetic.
//

import SwiftUI

extension Color {
    @MainActor static var appAccent: Color {
        AppContainer.shared.settings.accentColor.color ?? .accentColor
    }
}

/// Standard glass pill styling for input fields and container rows.
struct GlassPillModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.15).shadow(.inner(color: Color.black.opacity(0.2), radius: 2, y: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassPillStyle() -> some View {
        self.modifier(GlassPillModifier())
    }
}

/// A glowing accent color button modifier used for active segments and the main download button.
struct GlowingButtonModifier: ViewModifier {
    var isActive: Bool
    var cornerRadius: CGFloat = 12
    @State private var isHovering = false
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .background(Color.white.opacity(isHovering ? 0.2 : 0.1)) // Glass material, slightly brighter
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isHovering ? 0.2 : 0.05), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.2), radius: isHovering ? 12 : 8, x: 0, y: isHovering ? 6 : 4)
                .scaleEffect(isHovering ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
                .onHover { hovering in
                    isHovering = hovering
                }
        } else {
            content
                .background(Color.clear)
        }
    }
}

extension View {
    func glowingButtonStyle(isActive: Bool = true, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(GlowingButtonModifier(isActive: isActive, cornerRadius: cornerRadius))
    }
}

/// Modifier for dark translucent input fields with rounded corners
struct InputFieldModifier: ViewModifier {
    var isFocused: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.15).shadow(.inner(color: Color.black.opacity(0.25), radius: 2, y: 1)))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isFocused ? Color.appAccent.opacity(0.8) : Color.white.opacity(0.05), lineWidth: isFocused ? 1.5 : 0.5)
            )
    }
}

extension View {
    func inputFieldStyle(isFocused: Bool = false) -> some View {
        self.modifier(InputFieldModifier(isFocused: isFocused))
    }
}

/// Custom button style for the radio buttons
struct RadioButtonStyle: ButtonStyle {
    var isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.appAccent : Color.white.opacity(0.1))
                    .frame(width: 14, height: 14)
                
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                }
            }
            
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        }
        .contentShape(Rectangle())
        .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

/// A custom, smooth glass segmented control with sliding animation
struct GlassSegmentedControl<T: Hashable & Identifiable & Equatable>: View {
    @Binding var selection: T
    var items: [T]
    var titleForItem: (T) -> String
    @Namespace private var namespace
    
    @State private var isDragging: Bool = false
    @State private var draggedItem: T? = nil
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(items) { item in
                    let isSelected = (isDragging ? draggedItem : selection) == item
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selection = item
                        }
                    } label: {
                        Text(titleForItem(item))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isDragging ? Color.appAccent.opacity(0.65) : Color.appAccent)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(isDragging ? 0.4 : 0.0), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(isDragging ? 0.3 : 0.15), radius: isDragging ? 5 : 3, y: 1)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let segmentWidth = geometry.size.width / CGFloat(max(1, items.count))
                        let index = Int(max(0, min(value.location.x / segmentWidth, CGFloat(items.count - 1))))
                        let item = items[index]
                        if draggedItem != item {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                draggedItem = item
                            }
                        }
                    }
                    .onEnded { value in
                        if let finalItem = draggedItem {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selection = finalItem
                            }
                        }
                        isDragging = false
                        draggedItem = nil
                    }
            )
        }
        .frame(height: 28) // Fixed height since GeometryReader takes available space
        .padding(2)
        .background(Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}

/// A custom toggle style matching a liquid glass / pill design with drag interactivity.
struct GlassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        GlassToggleView(configuration: configuration)
    }
}

struct GlassToggleView: View {
    let configuration: ToggleStyle.Configuration
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            configuration.label
            Spacer()
            
            let knobWidth: CGFloat = 24
            let knobHeight: CGFloat = 22
            let trackWidth: CGFloat = 52
            let trackHeight: CGFloat = 28
            
            let maxOffset = (trackWidth - knobWidth) / 2 - 2
            let minOffset = -maxOffset
            let currentOffset = configuration.isOn ? maxOffset : minOffset
            
            RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                .fill(configuration.isOn ? (isDragging ? Color.appAccent.opacity(0.65) : Color.appAccent) : Color.white.opacity(0.1))
                .frame(width: trackWidth, height: trackHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: trackHeight / 2, style: .continuous)
                        .stroke(Color.white.opacity(isDragging ? 0.4 : 0.1), lineWidth: 1)
                        .blendMode(.overlay)
                )
                .shadow(color: Color.black.opacity(isDragging ? 0.3 : 0.15), radius: isDragging ? 5 : 3, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.92, green: 0.95, blue: 1.0))
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                        .frame(width: knobWidth + (isDragging ? 6 : 0), height: knobHeight)
                        .offset(x: currentOffset + dragOffset)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let proposedOffset = value.translation.width
                            
                            if configuration.isOn {
                                dragOffset = max(minOffset - maxOffset, min(0, proposedOffset))
                            } else {
                                dragOffset = min(maxOffset - minOffset, max(0, proposedOffset))
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            
                            let totalOffset = currentOffset + dragOffset
                            let threshold: CGFloat = 0
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if totalOffset > threshold && !configuration.isOn {
                                    configuration.isOn = true
                                } else if totalOffset < threshold && configuration.isOn {
                                    configuration.isOn = false
                                } else if value.translation.width == 0 {
                                    configuration.isOn.toggle()
                                }
                                dragOffset = 0
                            }
                        }
                )
        }
    }
}

extension ToggleStyle where Self == GlassToggleStyle {
    static var glass: GlassToggleStyle { GlassToggleStyle() }
}

/// Simple toolbar hover button style with no explicit borders
struct ToolbarHoverButtonStyle: ButtonStyle {
    @State private var isHovering = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering || configuration.isPressed ? Color.white.opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(.easeOut(duration: 0.1), value: isHovering)
    }
}
