#!/usr/bin/env perl

use strict;
use warnings;
use v5.30;

use XML::Feed;
use LWP::UserAgent;
use URI;
use Try::Tiny;
use Path::Tiny;
use Log::Log4perl qw(:easy);
use LWP::Protocol::https;
use YAML::XS qw(LoadFile);
use Getopt::Long;
use HTTP::Request;

# https://misc.flogisoft.com/bash/tip_colors_and_formatting
my $cRed = "\e[31m";
my $cGreen = "\e[32m";
my $cYellow = "\e[33m";
my $cClear = "\e[0m";


binmode(STDOUT, ":encoding(UTF-8)");

# Konfiguration laden
my $config_file = 'config.yml';
GetOptions('config=s' => \$config_file) or die "${cRed}Error parsing commandline options${cClear}\n";

# Lade und validiere Konfiguration
my $config = eval { LoadFile($config_file) };
die "${cRed}Error reading $config_file:${cClear} $@" if $@;

die "Unknown config option: 'settings' fehlt\n" unless $config->{settings};
die "Unknown config option: 'feeds' fehlt\n" unless $config->{feeds};

# Initialisiere Logging
#Log::Log4perl->easy_init($INFO);
Log::Log4perl->easy_init(
    {
        level => $INFO,
        utf8  => 1,
    }
);

# Konfiguration
my $settings = $config->{settings};
my $download_dir = path($settings->{download_dir})->absolute;

INFO("Use download folder: $download_dir");

# Erstelle User Agent mit Konfiguration
my $ua = LWP::UserAgent->new(
    agent => $settings->{user_agent} // 'PodcastDownloader (poddl.pl)/1.0.0',
    timeout => $settings->{timeout} // 30,
    ssl_opts => { verify_hostname => 1 },
    max_redirect => $settings->{max_redirects} // 5,
);

# Überprüfe Download-Verzeichnis
sub check_download_dir {
    my ($dir) = @_;
    
    # Prüfe ob das Verzeichnis existiert
    if (!-e $dir) {
        ERROR("${cRed}download folder not existing: $dir${cClear}");
        return 0;
    }
    
    # Prüfe ob es ein Verzeichnis ist
    if (!-d $dir) {
        ERROR("${cRed}$dir not a folder${cClear}");
        return 0;
    }
    
    # Prüfe Schreibrechte
    if (!-w $dir) {
        ERROR("${cRed}No write permissons on $dir${cClear}");
        return 0;
    }
    
    return 1;
}

sub show_download_progress {
    my ($feed_name, $filename, $bytes_received, $total_bytes) = @_;
    my $percent = $total_bytes ? int(($bytes_received / $total_bytes) * 100) : 0;
    my $bar_width = 40;
    my $filled = $total_bytes ? int(($bar_width * $bytes_received) / $total_bytes) : 0;
    my $empty = $bar_width - $filled;
    
    my $bar = "[" . ("#" x $filled) . ("-" x $empty) . "]";
    my $size_info = $total_bytes ? sprintf("%.1f/%.1f MB", $bytes_received/(1024*1024), $total_bytes/(1024*1024)) : sprintf("%.1f MB", $bytes_received/(1024*1024));
    printf("\r                    [${cGreen}${feed_name}${cClear}] %s %s %3d%% %s", $filename, $bar, $percent, $size_info);
}

sub check_existing_file {
    my ($file_path, $expected_size) = @_;
    
    return 0 unless -f $file_path;  # Datei existiert nicht
    if ($settings->{check_filesize}) {
        return 0 unless $expected_size; # Keine Größeninformation verfügbar
    } else {
    	return 1;
    }
    
    my $current_size = -s $file_path;
    return 1 if $current_size == $expected_size;  # Datei ist vollständig
    
    # Datei existiert, ist aber unvollständig
    INFO("File already exists, BUT wrong with size ($current_size/$expected_size Bytes) - re-download");
    return 0;
}

# Hilfsfunktion zum Kürzen von Dateinamen
sub truncate_filename {
    my ($filename, $max_length) = @_;
    $max_length //= 100;  # Standardlänge, falls nicht angegeben
    
    # Dateiendung extrahieren
    my ($name, $ext) = $filename =~ /(.+)\.([^.]+)$/;
    return $filename if !$name || !$ext;  # Keine Dateiendung gefunden
    
    # Wenn der Name bereits kürzer ist, unverändert zurückgeben
    return $filename if length($filename) <= $max_length;
    
    # Name kürzen und Dateiendung wieder anhängen
    return substr($name, 0, $max_length - length($ext) - 1) . '.' . $ext;
}

sub download_file {
    my ($url, $filename, $feed_name, $cdate) = @_;
    
    # Überprüfe Download-Verzeichnis vor jedem Download
    unless (check_download_dir($download_dir)) {
        ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}Download of $filename candeled - error with download folder${cClear}");
        return 0;
    }
    
    # Erstelle Feed-spezifisches Unterverzeichnis
    my $feed_dir = $download_dir->child($feed_name);
    $feed_dir->mkpath;
    my $file_path = $feed_dir->child($filename);
    my $head_response;
    
    # Hole die Dateigröße
    my $total_bytes = 0;
    if ($settings->{check_filesize}) {
        $head_response = $ua->head($url);
        $total_bytes = $head_response->header('Content-Length') // 0;
    }

    # Prüfe, ob die Datei bereits vollständig heruntergeladen wurde
    if (check_existing_file($file_path, $total_bytes)) {
        INFO("[${cGreen}${feed_name}${cClear}] File already downloaded: $filename") if ($settings->{only_new_info});
        if ($settings->{check_pubDate}) {
            INFO("[${cGreen}${feed_name}${cClear}] touch -t $cdate '$file_path'") if ($settings->{only_new_info});
            `touch -t $cdate '$file_path'`;
        }
        return 1;
    } else {
        $head_response = $ua->head($url);
        $total_bytes = $head_response->header('Content-Length') // 0;
        INFO("[${cGreen}${feed_name}${cClear}] New file found: $filename ($total_bytes Bytes)");
    }
    
    if ($total_bytes <= 2) {
        INFO("[${cGreen}${feed_name}${cClear}] Content-Length Header wrong format: $total_bytes");
        $total_bytes = 0;
    }
    
    INFO("[${cGreen}${feed_name}${cClear}] Download: $filename having $total_bytes Bytes");
    INFO("[${cGreen}${feed_name}${cClear}] URL: $url");
    
    # Erstelle HTTP-Request
    my $request = HTTP::Request->new(GET => $url);
    my $bytes_received = 0;
    my $content = '';
    
    my $response = $ua->request($request, sub {
        my ($data, $response, $protocol) = @_;
        $bytes_received += length($data);
        $content .= $data;  # Sammle die Daten
        show_download_progress($feed_name, $filename, $bytes_received, $total_bytes) unless ($bytes_received > $total_bytes);
        return 1;
    });
    INFO("\n");
    
    # Überprüfe auf Redirects und folge ihnen manuell falls nötig
    if ($response->is_redirect) {
        my $redirect_count = 0;
        my $max_redirects = $settings->{max_redirects} // 5;
        
        while ($response->is_redirect && $redirect_count < $max_redirects) {
            my $new_url = $response->header('Location');
            INFO("[${cGreen}${feed_name}${cClear}] Follow redirect to: $new_url");
            
            
            # Hole neue Dateigröße
            $head_response = $ua->head($new_url);
            $total_bytes = $head_response->header('Content-Length') // 0;

            if ($total_bytes <= 2) {
                INFO("[${cGreen}${feed_name}${cClear}] Content-Length Header wrong: $total_bytes");
                $total_bytes = 0;
            }
    
            # Prüfe erneut nach Redirect
            if (check_existing_file($file_path, $total_bytes)) {
                INFO("[${cGreen}${feed_name}${cClear}] Aready downloaded sccueesfully: $filename");
                return 1;
            }
            
            $bytes_received = 0;
            $content = '';  # Setze Content zurück für neuen Download
            
            $request = HTTP::Request->new(GET => $new_url);
            $response = $ua->request($request, sub {
                my ($data, $response, $protocol) = @_;
                $bytes_received += length($data);
                $content .= $data;  # Sammle die Daten
                show_download_progress($feed_name, $filename, $bytes_received, $total_bytes) unless ($bytes_received > $total_bytes);
                return 1;
            });
            INFO("\n");

            $redirect_count++;
        }
        
        if ($redirect_count >= $max_redirects) {
            ERROR("\n");
            ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}Too many redirects for URL: $url${cClear}");
            return 0;
        }
    }
    
    if ($response->is_success) {
        $file_path->spew_raw($content);  # Speichere die gesammelten Daten
        
        # Überprüfe die Größe der gespeicherten Datei
        my $final_size = -s $file_path;
        if ($total_bytes && $final_size != $total_bytes) {
            ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}Error saving $filename: filesize does not match ($final_size != $total_bytes)${cClear}");
            return 0;
        }
        
        # bei neuen Dateien wird das Creation-Date immer korrigiert
        INFO("[${cGreen}${feed_name}${cClear}] touch -t $cdate '$file_path'");
        `touch -t $cdate '$file_path'`;

        INFO("\n");
        INFO("[${cGreen}${feed_name}${cClear}] Download sccueesfull: $filename");
        return 1;
    } else {
        ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}Error downloding $url: " . $response->status_line . "${cClear}");
        return 0;
    }
    
    INFO("\n");
}

sub process_feed {
    my $feed_config = shift;
    my $processed_urls = shift || {};
    
    return unless $feed_config->{enabled};
    
    my $feed_name = $feed_config->{name};
    my $feed_url = $feed_config->{url};
    
    # Verhindere Endlosschleifen durch bereits verarbeitete URLs
    if ($processed_urls->{$feed_url}) {
        INFO("[${cGreen}${feed_name}${cClear}] Feed URL already handled: $feed_url");
        return;
    }
    $processed_urls->{$feed_url} = 1;
    
    INFO("Analyse feed: $feed_name ($feed_url)");
    
    try {
        # Erstelle einen separaten User Agent für Feed-Downloads
        my $feed_ua = LWP::UserAgent->new(
            agent => $settings->{user_agent} // 'PodcastDownloader (poddl.pl)/1.0.0',
            timeout => $settings->{timeout} // 30,
            ssl_opts => { verify_hostname => 1 },
            max_redirect => $settings->{max_redirects} // 5,
        );
        
        my $feed_response = $feed_ua->get($feed_url);
        
        if (!$feed_response->is_success) {
            die "Error downloding feed: " . $feed_response->status_line;
        }
        
        my $feed_content = $feed_response->content;
        my $feed = XML::Feed->parse(\$feed_content)
            or die XML::Feed->errstr;
        
        my @entries = $feed->entries;
        my $total_entries = scalar @entries;
        INFO("${cYellow}##############################################################${cClear}");
        INFO("[${cGreen}${feed_name}${cClear}] ${cYellow}found: $total_entries Einträge${cClear}");
        
        my $downloaded_entries = 0;
        my $failed_entries = 0;
        
        for my $entry (@entries) {
            my $title = $entry->title;
            my $filelink = $entry->link;
            my $enclosure = $entry->enclosure;
            my $pub_date = $entry->issued;  # Extrahiere das Publikationsdatum
            
            # Formatiere das Datum
            my $formatted_date = '';
            if ($pub_date) {
                $formatted_date = $pub_date->strftime("%Y%m%d%H%M.%S");
                # INFO("[${cGreen}${feed_name}${cClear}] Publikationsdatum für '$title': $formatted_date");
            }
            
            next unless $enclosure;
            
            my $url = $enclosure->url;
            my $type = $enclosure->type;

            my $filename = "";
            if (length($title)) {
                $filename = $title;
            } else {
                $filelink =~ /([^\/]+)$/;
                $filename = $1;
            }
            
            INFO("[${cGreen}${feed_name}${cClear}] ${cYellow}Analysing: ${filename}${cClear}");
            # Erstelle sicheren Dateinamen aus dem Titel
            $filename =~ s/[^a-zA-Z0-9]/_/g;
            $filename .= '.' . guess_extension($type);
            $filename = truncate_filename($filename, 150);  # Kürze auf 150 Zeichen

            # Erster Versuch
            my $success = try {
                return download_file($url, $filename, $feed_name, $formatted_date);
            } catch {
                ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}First download with error for $filename: $_${cClear}");
                return 0;
            };
            
            # Zweiter Versuch bei Fehler
            if (!$success) {
                INFO("[${cGreen}${feed_name}${cClear}] Start 2nd download for: $filename");
                $success = try {
                    return download_file($url, $filename, $feed_name, $formatted_date);
                } catch {
                    ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}2nd downloadwith error for $filename: $_, too${cClear}");
                    return 0;
                };
            }
            
            if ($success) {
                $downloaded_entries++;
            } else {
                $failed_entries++;
            }
        }
        
        INFO("[${cGreen}${feed_name}${cClear}] Download finished: $downloaded_entries of $total_entries entries downloaded, $failed_entries with error.");
        
        # Suche nach 'next' Link im Feed
        if ($feed_content =~ /<atom:link[^>]*rel="next"[^>]*href="([^"]+)"/) {
            my $next_url = $1;
            INFO("[${cGreen}${feed_name}${cClear}] Found: next feed URL: $next_url");
            
            # Rekursiv den nächsten Feed verarbeiten
            my $next_feed_config = {
                name => $feed_name,
                url => $next_url,
                enabled => 1
            };
            process_feed($next_feed_config, $processed_urls);
        }
        
    } catch {
        ERROR("[${cGreen}${feed_name}${cClear}] ${cRed}Error analysing feed: $_${cClear}");
    };
}

sub guess_extension {
    my ($mime_type) = @_;
    my $mime_type_info = $mime_type;
    $mime_type_info =~ s/\//_/;

    return 'mp3' if $mime_type =~ /audio\/mp3/;
    return 'mp3' if $mime_type =~ /audio\/mpeg/;
    return 'm4a' if $mime_type =~ /audio\/x-m4a/;
    return 'm4a' if $mime_type =~ /audio\/mp4/;
    return 'mp4' if $mime_type =~ /video\/mp4/;
    return 'ogg' if $mime_type =~ /audio\/ogg/;
    return 'unknown (' . $mime_type_info . ')';
}

# Hauptprogramm
INFO("Start Podcast-Downloader");
INFO("Read config.yml: $config_file");

my $total_feeds = scalar(grep { $_->{enabled} } @{$config->{feeds}});
INFO("Analyse $total_feeds active feeds");

for my $feed (@{$config->{feeds}}) {
    process_feed($feed);
}

INFO("Downloads finished"); 
