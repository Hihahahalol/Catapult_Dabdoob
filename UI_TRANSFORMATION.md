# Dabdoob Launcher UI Transformation

## Overview
The Dabdoob launcher UI has been transformed from a generic, utilitarian design to a polished, modern launcher interface with improved visual hierarchy, better spacing, and more intuitive controls.

## Key Changes

### Header Section
- **App Branding**: Now displays "Dabdoob" with subtitle "a launcher for Cataclysm" for clear identity
- **Title Bar**: Updated to show "Dabdoob — a launcher for Cataclysm" 
- **Game Selection**: Moved to the right side of the header with "Cataclysm: The Last Generation" as default
- **Window Controls**: Minimize, maximize, and close buttons properly positioned on the right
- **Spacing**: Increased from 4px to 12px margins for better breathing room

### Game Information Section
- **Info Button**: Circular "ⓘ" button on the left for game info access
- **Description**: Prominent game description displayed alongside the info button
- **Typography**: Enhanced color hierarchy with better contrast
- **Height**: Optimized to 68px for balanced layout

### Tab Navigation
- **Cleaner Layout**: Tabs for Game, Mods, Tilesets, Soundpacks, Fonts, Backups, Settings, About
- **Visual Hierarchy**: Tab bar aligned horizontally with improved spacing
- **Boundaries**: Clear separation between tab content and main layout

### Release Channel Section
- **Label Styling**: "Release Channel:" with better visual weight
- **Radio Buttons**: Modern checkbox-style buttons for Stable/Experimental selection
- **Changelog Link**: Blue "View Changelog" link on the right side (color: #5DA5DA)
- **Spacing**: 8px separation between components, 16px between button groups

### Builds Section
- **Container**: Organized in a dedicated BuildsContainer with clear visual grouping
- **Label**: "Available builds:" label with consistent styling
- **Dropdown**: Clean option button with proper sizing
- **Refresh Button**: Styled button (not text label) on the right
- **Install Button**: Centered "Install Selected" button below the dropdown
- **Checkbox**: "Update current active install" checkbox with proper text
- **Vertical Spacing**: 10px between sub-sections for clarity

### Active Install Section
- **Header**: "Active Install:" label with consistent styling
- **Version Display**: Clean version display with settings and user folder icons
- **Launch Controls**: 
  - "Play" button for starting new game
  - "Resume Last World" button for continuing
  - Search input and "Search Wiki" button in same row
- **Update Button**: "Update Dabdoob" button centered below
- **Organization**: Grouped in LaunchControls container with 8px separation

### Installs List
- **Hidden by Default**: GameInstalls section set to `visible = false`
- **Clean Layout**: Only shown when explicitly needed
- **Minimal UI**: Reduces clutter in normal usage

### Overall Styling

#### Colors
- **Bright Text**: Color(0.95, 0.95, 0.95, 1.0) for primary labels
- **Subtitle Text**: Color(0.7, 0.7, 0.8, 1.0) for secondary information
- **Description Text**: Color(0.75, 0.75, 0.75, 1.0) for longer text
- **Log Text**: Color(0.7, 0.7, 0.75, 1.0) for background console
- **Changelog Link**: #5DA5DA (light blue) for clickable links

#### Typography
- **App Title**: 20pt font, bright white
- **App Subtitle**: 12pt font, muted color
- **Section Labels**: 14pt font, consistent styling
- **Body Text**: Standard size with improved contrast

#### Spacing
- **Container Margins**: 12px on left and right (increased from 4px)
- **Container Top/Bottom**: 12px padding
- **Section Separation**: 8-12px between major sections
- **Component Spacing**: 8px between related controls

#### Layout Structure
```
Catapult (Panel)
├── TitleBar
└── Main (VBoxContainer, 12px margins)
    ├── HeaderSection (HBoxContainer, 12px separation)
    │   ├── AppBranding (VBoxContainer)
    │   │   ├── AppTitle (Label, 20pt)
    │   │   └── AppSubtitle (Label, 12pt)
    │   └── GameSelectContainer (HBoxContainer, right-aligned)
    │       └── GamesList (OptionButton)
    ├── GameInfo (HBoxContainer, 12px separation)
    │   ├── InfoButton (Button, circular)
    │   └── Description (RichTextLabel)
    ├── Spacer
    └── TabBar (TabContainer)
        └── Game (VBoxContainer)
            ├── Channel (VBoxContainer, 8px separation)
            │   ├── ChannelHeader (HBoxContainer)
            │   │   ├── ChannelLabel
            │   │   ├── Spacer
            │   │   └── ChangelogLink (blue, clickable)
            │   └── Group (HBoxContainer, 16px separation)
            │       ├── RBtnStable (CheckBox, "Stable")
            │       └── RBtnExperimental (CheckBox, "Experimental")
            ├── BuildsContainer (VBoxContainer, 10px separation)
            │   ├── Builds (HBoxContainer)
            │   │   ├── BuildsLabel
            │   │   ├── BuildsList (OptionButton)
            │   │   └── BtnRefresh (Button)
            │   └── ButtonContainer (VBoxContainer, 8px separation)
            │       ├── BtnInstall (centered button)
            │       └── UpdateCurrent (CheckBox)
            ├── HSeparator
            └── ActiveInstall (VBoxContainer, 12px separation)
                ├── ActiveInstallHeader (HBoxContainer)
                │   ├── ActiveInstallLabel
                │   └── Spacer
                ├── Build (HBoxContainer, 8px separation)
                │   ├── Name (version label)
                │   ├── GameDir (icon button)
                │   └── UserDir (icon button)
                └── LaunchControls (VBoxContainer, 8px separation)
                    ├── Launch (HBoxContainer)
                    │   ├── BtnPlay
                    │   ├── BtnResume
                    └── WikiSearch (HBoxContainer, 8px separation)
                        ├── WikiSearchInput
                        └── BtnSearchWiki
                    └── Update (VBoxContainer)
                        └── BtnUpdate (centered)
    └── Log (RichTextLabel)
```

## Node Path Changes

The following node paths were updated to accommodate the new structure:

### Script References (Catapult.gd)
- `_btn_install`: `$Main/TabBar/Game/BuildsContainer/ButtonContainer/BtnInstall`
- `_btn_refresh`: `$Main/TabBar/Game/BuildsContainer/Builds/BtnRefresh`
- `_btn_play`: `$Main/TabBar/Game/ActiveInstall/LaunchControls/Launch/BtnPlay`
- `_btn_resume`: `$Main/TabBar/Game/ActiveInstall/LaunchControls/Launch/BtnResume`
- `_wiki_search_input`: `$Main/TabBar/Game/ActiveInstall/LaunchControls/WikiSearch/WikiSearchInput`
- `_btn_search_wiki`: `$Main/TabBar/Game/ActiveInstall/LaunchControls/WikiSearch/BtnSearchWiki`
- `_btn_update`: `$Main/TabBar/Game/ActiveInstall/LaunchControls/Update/BtnUpdate`
- `_lst_builds`: `$Main/TabBar/Game/BuildsContainer/Builds/BuildsList`
- `_lst_games`: `$Main/HeaderSection/GameSelectContainer/GamesList`
- `_cb_update`: `$Main/TabBar/Game/BuildsContainer/ButtonContainer/UpdateCurrent`

### Scene Connections (Catapult.tscn)
All signal connections have been updated to reflect the new node hierarchy:
- BuildsList selections from new path
- BtnRefresh signals from BuildsContainer
- BtnInstall signals from ButtonContainer
- UpdateCurrent checkbox signals from ButtonContainer
- Play/Resume buttons from LaunchControls
- Wiki search signals from LaunchControls/WikiSearch
- InfoButton pressed signal instead of GameInfo/Icon gui_input

## Visual Improvements

### Before
- Generic labels with "lbl_" prefix
- Inconsistent spacing (4px margins)
- Text-based buttons with "btn_" prefix
- No visual hierarchy in sections
- Cluttered information display

### After
- Semantic, descriptive labels
- Generous spacing (12px margins)
- Styled button controls
- Clear visual grouping with containers
- Organized information flow

## Design Principles Applied

1. **Visual Hierarchy**: Larger fonts for primary elements, smaller for secondary
2. **Spacing**: Generous margins and padding for breathing room
3. **Color Consistency**: Coordinated color scheme with subtle variations
4. **Component Grouping**: Related controls in dedicated containers
5. **Typography**: Clear distinction between headings and body text
6. **Accessibility**: Better contrast ratios and readable font sizes

## Testing Checklist

- [ ] All buttons are properly visible and clickable
- [ ] Text labels display with correct font sizes and colors
- [ ] Spacing appears balanced and intentional
- [ ] Game selection dropdown functions correctly
- [ ] Changelog link is clickable and styled correctly
- [ ] Release channel buttons work as expected
- [ ] Install button launches installer
- [ ] Wiki search input and button function
- [ ] Play and Resume buttons work correctly
- [ ] Update Dabdoob button is functional
- [ ] Tab navigation works smoothly
- [ ] Log messages appear at bottom with proper styling
- [ ] Window resize maintains layout integrity
- [ ] All tooltips display correctly

## Future Enhancement Opportunities

1. Add hover effects to buttons for better UX
2. Implement button icons for visual enhancement
3. Add animations for tab transitions
4. Create custom theme variations
5. Add dark/light mode support
6. Implement accessibility improvements
7. Add keyboard navigation shortcuts
8. Create responsive layout for smaller screens
