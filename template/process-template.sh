#!/bin/bash

TEMPLATE_DIR="${1:-template}"
SETTINGS_DIR="${2:-settings}"
OUTPUT_DIR="${3:-.}"

cd "$(dirname "$0")"
cd ..
source "$TEMPLATE_DIR/helper.sh"

dir=$(basename "$TEMPLATE_DIR")
if [ "$dir" != "template" ] && [ "$dir" != "$TEMPLATE_DIR" ]; then
  :
fi

[ -d "$TEMPLATE_DIR/img" ] && mv "$TEMPLATE_DIR/img" "$OUTPUT_DIR/" && echo "img copied to site root"

SITE_JSON="$SETTINGS_DIR/site.json"

build_css() {
  local css_output=$(json_nested "$SITE_JSON" assets cssOutput)
  [ -z "$css_output" ] && css_output="site.css"
  local files=$(json_nested_array "$SITE_JSON" assets css)
  if [ -n "$files" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && min "$TEMPLATE_DIR/$f"
    done <<< "$files"
  else
    min "$TEMPLATE_DIR/css/base.css"
    min "$TEMPLATE_DIR/css/layout.css"
    min "$TEMPLATE_DIR/css/page.css"
    min "$TEMPLATE_DIR/css/product.css"
    min "$TEMPLATE_DIR/css/basket.css"
  fi > "$OUTPUT_DIR/$css_output"

  echo "css merged"
}

build_js() {
  local js_output=$(json_nested "$SITE_JSON" assets jsOutput)
  [ -z "$js_output" ] && js_output="site.js"
  {
    # Include shipping.js from settings (customer-editable)
    [ -f "$SETTINGS_DIR/shipping.js" ] && min "$SETTINGS_DIR/shipping.js"

    local files=$(json_nested_array "$SITE_JSON" assets js)
    if [ -n "$files" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] && min "$TEMPLATE_DIR/$f"
      done <<< "$files"
    else
      min "$TEMPLATE_DIR/js/lazy.js"
      min "$TEMPLATE_DIR/js/off.js"
      min "$TEMPLATE_DIR/js/menu.js"
      min "$TEMPLATE_DIR/js/helper.js"
      min "$TEMPLATE_DIR/js/basket.js"
    fi
  } > "$OUTPUT_DIR/$js_output"

  echo "js merged"
}

build_images() {
  if ! command -v ffmpeg &>/dev/null; then
    echo "ffmpeg not found. ffmpeg is required for image conversion."
    read -rp "Install ffmpeg? (y/n): " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
      sudo dnf install -y ffmpeg
      if ! command -v ffmpeg &>/dev/null; then
        echo "ffmpeg installation failed, skipping images."
        return 1
      fi
    else
      echo "ffmpeg not installed, skipping images."
      return 0
    fi
  fi

  for jpg in "$OUTPUT_DIR/img/pages"/*.jpg; do
    [ -f "$jpg" ] || continue
    base="${jpg%.jpg}"
    [ -f "${base}.webp" ] || ffmpeg -y -i "$jpg" -c:v libwebp -quality 80 "${base}.webp" 2>/dev/null
    [ -f "${base}-k.webp" ] || ffmpeg -y -i "$jpg" -vf "scale=20:-1,boxblur=2:1" -c:v libwebp -quality 88 "${base}-k.webp" 2>/dev/null
  done

  for jpg in "$OUTPUT_DIR/img/products"/*.jpg; do
    [ -f "$jpg" ] || continue
    base="${jpg%.jpg}"
    [ -f "${base}.webp" ] || ffmpeg -y -i "$jpg" -vf "scale=800:-1" -c:v libwebp -quality 80 "${base}.webp" 2>/dev/null
    [ -f "${base}-k.webp" ] || ffmpeg -y -i "$jpg" -vf "scale=20:-1,boxblur=2:1" -c:v libwebp -quality 88 "${base}-k.webp" 2>/dev/null
  done

  [ -f "$OUTPUT_DIR/logo.webp" ] || ffmpeg -y -i "$OUTPUT_DIR/logo.png" -vf "scale=-1:200" -c:v libwebp -quality 90 "$OUTPUT_DIR/logo.webp" 2>/dev/null

  echo "images processed"
}

build_css
build_js
build_images
