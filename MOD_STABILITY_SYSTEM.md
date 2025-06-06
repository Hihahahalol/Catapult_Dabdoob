# Mod Stability System

## Overview

The mod stability system provides compatibility checking for mods when using the experimental game channel. It determines whether a mod is likely to be compatible based on how recently the mod itself has been updated relative to its assigned stability rating.

## How It Works

### When Compatibility Checking Occurs

- **Only on experimental channel**: Compatibility checking only runs when the "experimental" channel is selected
- **Triggered on Mods tab**: When the user clicks on the "Mods" tab, the system automatically checks all available mods
- **Real-time updates**: Mod information displays are updated to show compatibility status

### Stability Ratings

Each mod has a manually assigned stability rating that determines how long it remains "supported" after its last release:

| Rating | Duration | Description |
|--------|----------|-------------|
| -1     | 1 week   | Very unstable, needs frequent updates |
| 0      | 1 month  | Unstable, needs regular updates |
| 1      | 3 months | Somewhat stable |
| 2      | 6 months | Moderately stable |
| 3      | 9 months | Stable |
| 4      | 1 year   | Very stable |
| 5      | 2 years  | Extremely stable |
| 100    | Forever  | Always compatible |

### Compatibility Logic

For each mod, the system:

1. **Gets the mod's latest release date** from its GitHub repository
2. **Calculates days since the mod's last release**
3. **Compares against the mod's stability rating**
4. **Determines compatibility**: A mod is compatible if `days_since_last_release <= stability_rating_duration`

### Example Mods (TLG)

Current mod assignments in the system:

- **Matter**: Stability rating 2 (6 months)
  - *Real GitHub data*: Fetched from https://github.com/Vegetabs/MindOverMatter-CTLG
- **BionicsExpanded**: Stability rating 1 (3 months)  
  - *Real GitHub data*: Fetched from https://github.com/Vegetabs/BionicsExpanded-CTLG
- **MythicalMartialArts**: Stability rating 0 (1 month)
  - *Real GitHub data*: Fetched from https://github.com/Vegetabs/MythicalMartialArts-CTLG

*Note: Compatibility is determined by comparing the actual latest release date from each mod's GitHub repository against its stability rating.*

## User Interface Features

### Visual Indicators

- **Compatible mods**: Normal text color
- **Incompatible mods**: Red text with "[INCOMPATIBLE]" prefix
- **Already installed mods**: Grayed out text

### Information Display

When viewing mod details in experimental mode, users see:

- **Stability Rating**: Shows the rating number and duration (e.g., "2 (6 months)")
- **Last Updated**: Shows the mod's last release date and days ago
- **Compatibility**: Color-coded status (green for compatible, red for incompatible)

### Installation Warnings

- **Pre-installation check**: Warns users when attempting to install incompatible mods
- **Batch installation**: Lists all incompatible mods in the selection
- **Status messages**: Reports overall compatibility statistics when opening the Mods tab

## Technical Implementation

### Key Files Modified

- **ModManager.gd**: Core compatibility logic, stability ratings, GitHub API integration
- **ModsUI.gd**: User interface updates, visual indicators, warnings
- **ReleaseManager.gd**: Enhanced to include release dates from GitHub API

### GitHub Integration

- **Real-time API calls**: Makes actual HTTP requests to GitHub API for each mod's latest release
- **Asynchronous processing**: Fetches multiple mod release dates simultaneously without blocking the UI
- **Intelligent caching**: Caches release dates to avoid repeated API calls during the same session
- **Authentication support**: Uses `Auth_Token.txt` file for higher GitHub API rate limits
- **Proxy support**: Handles proxy settings and network configurations
- **Graceful fallback**: Shows "Fetching..." status while loading, handles API failures elegantly

### Real GitHub API Integration

The system now makes actual HTTP requests to GitHub's REST API:

- **Endpoint**: `https://api.github.com/repos/{owner}/{repo}/releases/latest`
- **Data extraction**: Parses the `published_at` field from JSON response
- **Rate limiting**: Respects GitHub API limits (60 requests/hour unauthenticated, 5000 with token)
- **Error handling**: Handles HTTP errors, malformed responses, and network issues

### Simulation Mode

**The system now uses real GitHub API calls by default.** Cached data is stored in memory during the session to improve performance.

## Configuration

### Adding New Mods

To add a new mod with stability checking:

1. Add the mod to the `available` dictionary in `ModManager.gd`
2. Include a `stability` field with the appropriate rating (0-5, 100, or -1)
3. Ensure the mod has a valid GitHub URL in the `location` field

### Adjusting Stability Ratings

Stability ratings are hardcoded in the `STABILITY_RATINGS` constant in `ModManager.gd` and can be modified as needed. 