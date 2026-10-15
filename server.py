#!/usr/bin/env python3
"""
Priviewer video server — run this file inside your video folder.
Serves all video files over HTTP on a single port.

Usage:
    pip install flask waitress
    python server.py [--port 8765]
"""

import os
import sys
import json
import socket
import mimetypes
import subprocess
import argparse
from pathlib import Path
from flask import Flask, Response, jsonify, abort, request

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

VIDEO_FOLDER = Path(__file__).parent.resolve()
VIDEO_EXTENSIONS = {'.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.flv', '.webm'}
CHUNK_SIZE = 1 * 1024 * 1024  # 1 MB streaming chunks
DEFAULT_PORT = 8765

mimetypes.add_type('video/x-matroska', '.mkv')
mimetypes.add_type('video/webm', '.webm')

app = Flask(__name__)

# In-memory index: filename -> absolute Path, rebuilt on each /videos request
_video_index: dict[str, Path] = {}
_duration_cache: dict[tuple, float | None] = {}  # (path_str, mtime) -> seconds


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def scan_videos() -> dict[str, Path]:
    index = {}
    for entry in VIDEO_FOLDER.iterdir():
        if entry.is_file() and entry.suffix.lower() in VIDEO_EXTENSIONS:
            index[entry.name] = entry
    return index


def get_duration(path: Path, mtime: float) -> float | None:
    key = (str(path), mtime)
    if key in _duration_cache:
        return _duration_cache[key]
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'quiet', '-print_format', 'json',
             '-show_format', str(path)],
            capture_output=True, text=True, timeout=5
        )
        data = json.loads(result.stdout)
        duration = float(data['format']['duration'])
    except Exception:
        duration = None
    _duration_cache[key] = duration
    return duration


def get_local_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'


def stream_file(path: Path, start: int, end: int):
    with open(path, 'rb') as f:
        f.seek(start)
        remaining = end - start + 1
        while remaining > 0:
            chunk = f.read(min(CHUNK_SIZE, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk


def parse_range(header: str, file_size: int) -> tuple[int, int] | None:
    """Parse 'bytes=start-end' header. Returns (start, end) or None on error."""
    if not header or not header.startswith('bytes='):
        return None
    try:
        range_spec = header[6:]
        if '-' not in range_spec:
            return None
        parts = range_spec.split('-', 1)
        start = int(parts[0]) if parts[0] else 0
        end = int(parts[1]) if parts[1] else file_size - 1
        if start > end or start >= file_size:
            return None
        end = min(end, file_size - 1)
        return start, end
    except ValueError:
        return None


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.after_request
def add_cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Range'
    return response


@app.route('/videos', methods=['GET'])
def list_videos():
    global _video_index
    _video_index = scan_videos()
    result = []
    for name, path in sorted(_video_index.items()):
        stat = path.stat()
        result.append({
            'id': name,
            'name': name,
            'size': stat.st_size,
            'mtime': stat.st_mtime,
            'duration': get_duration(path, stat.st_mtime),
        })
    return jsonify(result)


@app.route('/sync/manifest', methods=['GET'])
def sync_manifest():
    global _video_index
    _video_index = scan_videos()
    videos = []
    for name, path in _video_index.items():
        stat = path.stat()
        videos.append({
            'name': name,
            'size': stat.st_size,
            'mtime': stat.st_mtime,
        })
    # Sort newest first so client can greedily fill budget from top
    videos.sort(key=lambda v: v['mtime'], reverse=True)
    import time
    return jsonify({'generated': time.time(), 'videos': videos})


@app.route('/videos/<path:name>', methods=['GET', 'HEAD'])
def serve_video(name: str):
    global _video_index
    if not _video_index:
        _video_index = scan_videos()

    # Security: only serve files that are in the scanned index
    if name not in _video_index:
        # Rescan once in case of new files
        _video_index = scan_videos()
        if name not in _video_index:
            abort(404)

    path = _video_index[name]
    file_size = path.stat().st_size
    mime_type = mimetypes.guess_type(name)[0] or 'application/octet-stream'

    # HEAD request — return headers only
    if request.method == 'HEAD':
        response = Response(status=200)
        response.headers['Content-Type'] = mime_type
        response.headers['Content-Length'] = file_size
        response.headers['Accept-Ranges'] = 'bytes'
        return response

    range_header = request.headers.get('Range')
    parsed = parse_range(range_header, file_size) if range_header else None

    if parsed is None:
        # Full file response
        def full_stream():
            yield from stream_file(path, 0, file_size - 1)
        response = Response(
            full_stream(),
            status=200,
            mimetype=mime_type,
        )
        response.headers['Content-Length'] = file_size
        response.headers['Accept-Ranges'] = 'bytes'
        return response

    start, end = parsed
    length = end - start + 1

    response = Response(
        stream_file(path, start, end),
        status=206,
        mimetype=mime_type,
    )
    response.headers['Content-Range'] = f'bytes {start}-{end}/{file_size}'
    response.headers['Content-Length'] = length
    response.headers['Accept-Ranges'] = 'bytes'
    return response


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Priviewer video server')
    parser.add_argument('--port', type=int, default=DEFAULT_PORT,
                        help=f'Port to listen on (default: {DEFAULT_PORT})')
    parser.add_argument('--dev', action='store_true',
                        help='Use Flask dev server instead of waitress')
    args = parser.parse_args()

    ip = get_local_ip()
    print(f'\n  Priviewer server starting...')
    print(f'  Video folder : {VIDEO_FOLDER}')
    print(f'  Access URL   : http://{ip}:{args.port}')
    print(f'  Port         : {args.port}')
    print()

    if args.dev:
        app.run(host='0.0.0.0', port=args.port, threaded=True)
    else:
        try:
            from waitress import serve
            serve(app, host='0.0.0.0', port=args.port, threads=8)
        except ImportError:
            print('  waitress not found, falling back to Flask dev server.')
            print('  For better performance: pip install waitress\n')
            app.run(host='0.0.0.0', port=args.port, threaded=True)
