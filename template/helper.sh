#!/bin/bash
# Shared helper functions for update.sh and process-template.sh

# --- Minifier ---
min() {
  sed 's/^ *//; s/ *$//; /^$/d; s/  */ /g' "$1"
}

# --- JSON Helpers ---
json_val() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}

json_flag() {
  grep -q "\"$2\"[[:space:]]*:[[:space:]]*true" "$1"
}

json_num() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' "$1" | head -1
}

json_img() {
  sed -n 's/.*"images"[[:space:]]*:[[:space:]]*\["\([^"]*\)".*/\1/p' "$1" | head -1
}

json_nested() {
  sed -n '/"'"$2"'"/,/^[[:space:]]*}/p' "$1" \
    | sed -n 's/.*"'"$3"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

json_label() {
  sed -n '/"labels"/,/}/p' "$SITE_JSON" \
    | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

# Read array items from a nested JSON section
# Usage: json_nested_array "file" "section" "key" → one value per line
json_nested_array() {
  sed -n '/"'"$2"'"/,/^[[:space:]]*}/p' "$1" \
    | tr '\n' ' ' \
    | sed -n 's/.*"'"$3"'"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p' \
    | tr ',' '\n' \
    | sed -n 's/.*"\([^"]*\)".*/\1/p'
}

# --- Arabic-Indic price display conversion ---
# _price_digit_pass: converts the rightmost remaining Western digit before ₺
# (digits already converted to Arabic-Indic are matched by [٠-٩]*)
_price_digit_pass() {
  sed '
    s/0\([٠-٩]* ₺\)/٠\1/g
    s/1\([٠-٩]* ₺\)/١\1/g
    s/2\([٠-٩]* ₺\)/٢\1/g
    s/3\([٠-٩]* ₺\)/٣\1/g
    s/4\([٠-٩]* ₺\)/٤\1/g
    s/5\([٠-٩]* ₺\)/٥\1/g
    s/6\([٠-٩]* ₺\)/٦\1/g
    s/7\([٠-٩]* ₺\)/٧\1/g
    s/8\([٠-٩]* ₺\)/٨\1/g
    s/9\([٠-٩]* ₺\)/٩\1/g
  '
}

# convert_price_digits: applies 5 passes — handles prices up to 5 digits
convert_price_digits() {
  printf '%s' "$1" \
    | _price_digit_pass | _price_digit_pass | _price_digit_pass \
    | _price_digit_pass | _price_digit_pass
}

# --- Utility ---
blur_src() {
  local src="$1"
  printf '%s' "${src%.webp}-k.webp"
}

# --- Routing ---
is_root_page() {
  echo ",$ROOT_PAGES," | grep -q ",$1,"
}

page_href() {
  local name="$1"
  if is_root_page "$name"; then
    printf '/%s.html' "$name"
  else
    printf '/%s/%s.html' "$PAGES_DIR" "$name"
  fi
}

page_output_path() {
  local name="$1"
  if is_root_page "$name"; then
    printf '%s/%s.html' "$OUTPUT_DIR" "$name"
  else
    printf '%s/%s/%s.html' "$OUTPUT_DIR" "$PAGES_DIR" "$name"
  fi
}

# --- Template Engine ---
render_template() {
  local content="$1"
  shift
  while [ $# -ge 2 ]; do
    local key="$1" val="$2"
    # Bash 5.2+: & and \ are special in replacement strings
    val="${val//\\/\\\\}"
    val="${val//&/\\&}"
    content="${content//\{\{$key\}\}/$val}"
    shift 2
  done
  printf '%s' "$content"
}

apply_layout() {
  local tpl_file="$1"
  shift
  local content tpl_dir
  content=$(<"$tpl_file")
  tpl_dir=$(dirname "$tpl_file")

  local partial_name partial_content partial_file
  while [[ "$content" == *'{{partial:'* ]]; do
    partial_name=$(printf '%s' "$content" \
      | grep -o '{{partial:[^}]*}}' | head -1 \
      | sed 's/{{partial:\([^}]*\)}}/\1/')
    [ -z "$partial_name" ] && break
    partial_file="$tpl_dir/partials/${partial_name}.html"
    partial_content=""
    [ -f "$partial_file" ] && partial_content=$(<"$partial_file")
    partial_content="${partial_content//\\/\\\\}"
    partial_content="${partial_content//&/\\&}"
    content="${content//\{\{partial:${partial_name}\}\}/$partial_content}"
  done

  local rendered
  rendered=$(render_template "$content" "$@")
  convert_price_digits "$rendered"
}
