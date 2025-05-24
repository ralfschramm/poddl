# Podcast Downloader - poddl.pl

A Perl script for downloading podcast episodes from RSS feeds.

## Features

- Automatic downloading of episodes from multiple podcast feeds
- Configuration via YAML file (`config.yml`)
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
  - Configurable output formats (txt, srt, vtt, etc.)
  - Separate transcript directory
  - Automatic transcription of new and existing episodes
  - Custom Whisper parameters support

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

## Configuration

Create a `config.yml` file with your podcast feed settings:

```yaml
settings:
  download_dir: downloads
  max_redirects: 5
  timeout: 30
  user_agent: PodcastDownloader/1.0
  silent: false    # Set to true to suppress info messages
  whisper:
    path: /usr/local/bin/whisper    # Path to whisper executable
    model: /path/to/whisper/model   # Path to whisper model file
    enabled: true                   # Enable/disable transcription
    seperate_transcript_folder: transcripts  # Folder for transcriptions
    params: "--output-txt --language de"    # Custom whisper parameters

feeds:
  - name: Example Podcast
    url: https://example.com/feed.xml
    enabled: true
```

## Transcription

The script supports automatic transcription of downloaded episodes using OpenAI Whisper:

1. Install Whisper following the [official instructions](https://github.com/openai/whisper)
2. Download a Whisper model (e.g., `base`, `small`, `medium`, or `large`)
3. Configure the paths and options in `config.yml`:
   - `whisper.path`: Path to the whisper executable
   - `whisper.model`: Path to the downloaded model file
   - `whisper.enabled`: Enable/disable transcription feature
   - `whisper.seperate_transcript_folder`: Directory for transcriptions
   - `whisper.params`: Custom parameters for whisper (e.g., language, output format)

Features:
- Transcriptions are stored in a separate directory
- Supports multiple output formats (txt, srt, vtt)
- Automatic transcription of new downloads
- Transcription of existing episodes if missing
- Custom Whisper parameters for language and other options
- Automatic cleanup of failed transcriptions

## Usage

Run the script:

```bash
perl bin/poddl.pl
```

The script will:
1. Validate the download directory
2. Process each enabled feed in the configuration
3. Download new episodes
4. Display publication dates for each episode

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

## Requirements

- Perl 5.30 or higher
- Required Perl modules (installed via cpanm):
  - XML::Feed
  - YAML
  - LWP::UserAgent
  - Try::Tiny
  - Log::Log4perl 
