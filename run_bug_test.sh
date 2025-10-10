#!/usr/bin/env bash

# Test script to verify the text-transform bug fix
# This script will:
# 1. Start the test server
# 2. Open the browser to the test page
# 3. Instructions for manual testing

echo "=========================================="
echo "Text Transform Bug Test"
echo "=========================================="
echo ""
echo "This test demonstrates the phx-disable-with bug with text-transform: uppercase"
echo ""
echo "Testing Steps:"
echo "1. The server will start on http://localhost:5001"
echo "2. Open your browser to http://localhost:5001"
echo "3. Open browser DevTools and inspect the 'Increase' button"
echo "4. Note: The button HTML says 'Increase' but CSS renders it as 'INCREASE'"
echo "5. Click the button - it should change to 'Saving...'"
echo "6. After 3 seconds, inspect the button again"
echo "7. BEFORE FIX: The HTML will be 'INCREASE' (bug - CSS applied to stored text)"
echo "8. AFTER FIX: The HTML will be 'Increase' (correct - original text restored)"
echo ""
echo "=========================================="
echo ""
echo "Starting test server..."
echo "Press Ctrl+C to stop the server when done testing"
echo ""

cd /home/naina/Documents/projects/phoenix_live_view
elixir test_text_transform_bug.exs
