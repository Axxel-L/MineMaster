# Layout patterns

- Vertical flow: `VStack`.
- Horizontal groups: `HStack`.
- Collections: `LazyVGrid` / `LazyHGrid`.
- Paging: `ScrollView` plus `.scrollTargetBehavior(.paging)`.
- Prefer `containerRelativeFrame` and layout modifiers.
- Avoid `GeometryReader` and `UIScreen.main.bounds`.
- Use safe-area padding for floating tab bars.
- Keep tap targets at least 44 by 44 points.
