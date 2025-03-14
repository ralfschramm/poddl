# Podcast Downloader - poddl.pl

A Perl script for downloading podcast episodes from RSS feeds.

## Features

- Automatic downloading of episodes from multiple podcast feeds
- Configuration via YAML file (`config.yml`)
- Directory validation before downloads
- Smart filename handling:
  - Automatic filename sanitization
  - Filename length limitation (max 60 characters)
  - File extension preservation
- Publication date display for each episode
- Progress tracking and detailed logging
- Error handling and retry mechanisms
- Support for RSS feed pagination ("next" links)
- Feed sorting (alphabetically by name in config)
- SSL/TLS support with certificate verification
- Configurable download timeouts and redirect limits

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
download_dir: downloads
max_redirects: 5
timeout: 30
user_agent: PodcastDownloader/1.0

feeds:
  - name: Example Podcast
    url: https://example.com/feed.xml
    enabled: true
```

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
