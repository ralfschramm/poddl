# Podcast Downloader - poddl.pl

A Perl script for downloading podcast episodes from RSS feeds.

## Features

- Automatic downloading of episodes from multiple podcast feeds
- Configuration via YAML file (`poddl.conf`)
- Directory validation before downloads
- Smart filename handling:
  - Automatic filename sanitization
  - Filename length limitation (max 150 characters)
  - File extension preservation
  - Smart truncation of display names (80 characters with [...])
- Publication date display for each episode
- Progress tracking and detailed logging
- Error handling and retry mechanisms
- Support for RSS feed pagination ("next" links)
- Feed sorting (alphabetically by name in config)
- SSL/TLS support with certificate verification
- Configurable download timeouts and redirect limits
- Silent mode support (suppress info messages)
- Advanced transcription support via OpenAI Whisper:
  - Configurable output formats (txt, srt, vtt, json, etc.)
  - Separate transcript directory with customizable name
  - Automatic transcription of new and existing episodes
  - Custom Whisper parameters support (e.g., processors, language)
  - Support for multiple Whisper models (tiny, base, small, medium, large)

## Installation

1. Ensure Perl (version 5.30 or higher) is installed
2. Install cpanminus (if not already installed):
   ```
   curl -L https://cpanmin.us | perl - --sudo App::cpanminus
   ```
3. Install dependencies:
   ```
   cpanm --installdeps .
   ```
4. (Optional) Install Whisper for transcription support:
   - Install Whisper following the [official instructions](https://github.com/openai/whisper)
   - Use `download-ggml-model.sh` to download a pre-converted model:
     ```bash
     ./download-ggml-model.sh large-v3-turbo
     ```

## Configuration

Create a `poddl.conf` file with your podcast feed settings:

```yaml
settings:
  download_dir: /path/to/downloads  # Absolute or relative path to download directory
  max_redirects: 5                  # Maximum number of redirects to follow
  timeout: 60                       # Download timeout in seconds
  check_pubDate: true              # Update file creation date to match publication date
  check_filesize: false            # Verify file size after download
  only_new_info: false             # Only show info for new downloads
  silent: false                    # Suppress info messages
  user_agent: "PodcastDownloader (poddl.pl)/1.0.0"
  whisper:
    path: /path/to/whisper-cli     # Path to whisper executable
    model: /path/to/model.bin      # Path to whisper model file
    params: "--processors 2 --output-json"  # Custom whisper parameters
    seperate_transscript_folder: "__ Transscription __"  # Custom transcript folder name

feeds:
  - name: "Example Podcast"
    url: "https://example.com/feed.xml"
    language: en                    # Optional: specify language for transcription
    transscript: true              # Enable/disable transcription for this feed
    enabled: true                  # Enable/disable feed
```

## Transcription

The script supports automatic transcription of downloaded episodes using OpenAI Whisper:

1. Install Whisper following the [official instructions](https://github.com/openai/whisper)
2. Download a Whisper model using the included script:
   ```bash
   ./download-ggml-model.sh <model-name>
   ```
   Available models:
   - tiny, tiny.en, tiny-q5_1, tiny.en-q5_1, tiny-q8_0
   - base, base.en, base-q5_1, base.en-q5_1, base-q8_0
   - small, small.en, small.en-tdrz, small-q5_1, small.en-q5_1, small-q8_0
   - medium, medium.en, medium-q5_0, medium.en-q5_0, medium-q8_0
   - large-v1, large-v2, large-v2-q5_0, large-v2-q8_0
   - large-v3, large-v3-q5_0, large-v3-turbo, large-v3-turbo-q5_0, large-v3-turbo-q8_0

3. Configure the paths and options in `poddl.conf`:
   - `whisper.path`: Path to the whisper executable
   - `whisper.model`: Path to the downloaded model file
   - `whisper.params`: Custom parameters for whisper (e.g., processors, output format)
   - `whisper.seperate_transscript_folder`: Custom directory name for transcriptions

Features:
- Transcriptions are stored in a separate directory with customizable name
- Supports multiple output formats (txt, srt, vtt, json)
- Automatic transcription of new downloads
- Transcription of existing episodes if missing
- Custom Whisper parameters for language and other options
- Automatic cleanup of failed transcriptions
- Support for multi-processor transcription
- JSON output format for advanced processing

## Usage

Run the script:

```bash
perl poddl.pl [--config custom_poddl.conf]
```

The script will:
1. Validate the download directory
2. Process each enabled feed in the configuration
3. Download new episodes
4. Display publication dates for each episode
5. Transcribe episodes if enabled (using configured Whisper settings)

## Supported Formats

- MP3 (audio/mpeg)
- M4A (audio/mp4)
- MP4 (video/mp4)
- OGG (audio/ogg)

## Error Handling

The script includes robust error handling for:
- Network issues
- Invalid feed URLs
- Missing download directory
- Permission problems
- Invalid file formats
- Transcription failures
- Model loading errors
- Redirect loops

## Requirements

- Perl 5.30 or higher
- Required Perl modules (installed via cpanm):
  - XML::Feed
  - YAML::XS
  - LWP::UserAgent
  - LWP::Protocol::https
  - URI
  - Try::Tiny
  - Path::Tiny
  - Term::ProgressBar
  - Log::Log4perl
- (Optional) Whisper for transcription support
