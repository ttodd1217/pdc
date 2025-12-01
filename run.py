from app import create_app
from app.config import Config
import os
import sys

app = create_app(Config)

if __name__ == '__main__':
    # Get port from environment or use default
    port = int(os.environ.get('PORT', 5001))
    host = os.environ.get('HOST', '127.0.0.1')  # Use 127.0.0.1 instead of 0.0.0.0 on Windows
    
    # Disable reloader on Windows to avoid socket issues
    # The reloader uses file descriptors that don't work well on Windows
    use_reloader = os.name != 'nt'  # Only use reloader on non-Windows systems
    
    # try:
    app.run(host=host, port=port, debug=True, use_reloader=use_reloader)
    # except OSError as e:
    #     if '10038' in str(e) or 'socket' in str(e).lower():
    #         print(f"\n⚠️  Socket error detected. Trying alternative configuration...")
    #         print(f"   This is a known Windows issue with Flask's reloader.\n")
    #         # Try without reloader and with threaded=False
    #         app.run(host=host, port=port, debug=False, use_reloader=False, threaded=False)
    #     else:
    #         raise

