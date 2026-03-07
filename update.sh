#!/bin/bash

# --- CLI Arguments ---
TEMPLATE_DIR="template"
SETTINGS_DIR="settings"
OUTPUT_DIR="."

while [ $# -gt 0 ]; do
  case "$1" in
    --template) TEMPLATE_DIR="$2"; shift 2;;
    --settings) SETTINGS_DIR="$2"; shift 2;;
    --output)   OUTPUT_DIR="$2"; shift 2;;
    *) shift;;
  esac
done

cd "$(dirname "$0")"
source "$TEMPLATE_DIR/helper.sh"

# --- Settings ---
SITE_JSON="$SETTINGS_DIR/site.json"
COMPANY_JSON="$SETTINGS_DIR/company.json"

SITE_DOMAIN=$(json_val "$SITE_JSON" domain)
SITE_CACHE_PREFIX=$(json_val "$SITE_JSON" cachePrefix)
SITE_LANG=$(json_val "$SITE_JSON" lang)
SITE_CURRENCY_SYMBOL=$(json_val "$COMPANY_JSON" currencySymbol)
PAGES_DIR=$(json_val "$SITE_JSON" pagesDir)
[ -z "$PAGES_DIR" ] && PAGES_DIR="pages"
PRODUCTS_DIR=$(json_val "$SITE_JSON" productsDir)
[ -z "$PRODUCTS_DIR" ] && PRODUCTS_DIR="products"

# rootPages as comma-separated string
ROOT_PAGES=$(sed -n 's/.*"rootPages"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' "$SITE_JSON" | tr -d '"[:space:]')

IS_CATEGORY_COLLAPSABLE=false
json_flag "$SITE_JSON" isCategoryCollapsable && IS_CATEGORY_COLLAPSABLE=true

PRODUCT_SECTIONS=()

load_product_sections() {
  local in_sections=0 cur_key="" cur_label="" key label line
  while IFS= read -r line; do
    [[ "$line" == *'"productSections"'* ]] && { in_sections=1; continue; }
    [ "$in_sections" -eq 0 ] && continue
    [[ "$line" =~ ^[[:space:]]*\] ]] && break
    key=$(echo "$line" | sed -n 's/.*"key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    label=$(echo "$line" | sed -n 's/.*"label"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -n "$key" ] && cur_key="$key"
    [ -n "$label" ] && cur_label="$label"
    if [[ "$line" == *"}"* ]] && [ -n "$cur_key" ]; then
      PRODUCT_SECTIONS+=("${cur_key}|${cur_label}")
      cur_key="" cur_label=""
    fi
  done < "$SITE_JSON"
}

[ "$IS_CATEGORY_COLLAPSABLE" = "true" ] && load_product_sections

# --- Parts Content Builder ---
build_main() {
  local file="$1"
  grep -q '"parts"' "$file" || return

  local html="" found=0 in_content=0 in_list=0

  while IFS= read -r line; do
    if [ $found -eq 0 ]; then
      [[ "$line" == *'"parts"'* ]] && found=1
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*\] ]]; then
      if [ $in_list -eq 1 ]; then
        html+="</ul>"; in_list=0
      elif [ $in_content -eq 1 ]; then
        in_content=0
      else
        break
      fi
      continue
    fi

    if [[ "$line" == *'"title"'* ]]; then
      local t=$(echo "$line" | sed 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
      [ -n "$t" ] && html+="<h3>${t}</h3>"
      continue
    fi

    [[ "$line" == *'"content"'* ]] && { in_content=1; in_list=0; continue; }
    [[ "$line" == *'"list"'* ]] && { in_list=1; in_content=0; html+="<ul>"; continue; }

    if [ $in_content -eq 1 ] || [ $in_list -eq 1 ]; then
      [[ "$line" == *'"'* ]] || continue
      local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
      [ -z "$v" ] && continue
      [ $in_content -eq 1 ] && html+="<p>${v}</p>"
      [ $in_list -eq 1 ] && html+="<li>${v}</li>"
    fi
  done < "$file"

  printf '%s' "${html//\\\"/\"}"
}

# --- Contact Builder (E7) ---
build_contact() {
  local file="$COMPANY_JSON"
  local map=$(json_val "$file" map)
  local phone=$(json_val "$file" phone)
  local email=$(json_val "$file" email)
  local tel=$(echo "$phone" | tr -d ' ')

  local legal=$(json_val "$file" legalName)

  local lbl_address=$(json_label address)
  local lbl_phone=$(json_label phone)
  local lbl_email=$(json_label email)
  local lbl_map=$(json_label showOnMap)

  local html="<address>"
  html+="<h3>${legal}</h3>"

  html+="<div><img src=\"/img/address.png\" alt=\"${lbl_address}\"><p>"
  local in_addr=0 first=1
  while IFS= read -r line; do
    [[ "$line" == *'"address"'* ]] && { in_addr=1; continue; }
    [ $in_addr -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
    if [ -n "$v" ]; then
      [ $first -eq 0 ] && html+="<br>"
      html+="${v}"; first=0
    fi
  done < "$file"
  html+="</p></div>"

  html+="<a href=\"tel:${tel}\"><img src=\"/img/phone.png\" alt=\"${lbl_phone}\"><p>${phone}</p></a>"
  html+="<a href=\"mailto:${email}\"><img src=\"/img/email.png\" alt=\"${lbl_email}\"><p>${email}</p></a>"
  [ -n "$map" ] && [ "$map" != "#" ] && html+="<a href=\"${map}\" target=\"_blank\"><img src=\"/img/map.png\" alt=\"${lbl_map}\"><p>${lbl_map}</p></a>"

  html+="</address>"
  printf '%s' "$html"
}

# --- Sitemap Products: grouped by category ---
build_sitemap_products_grouped() {
  local html=""
  for section in "${PRODUCT_SECTIONS[@]}"; do
    IFS='|' read -r sec_key sec_label <<< "$section"
    local items=""
    for pj in "$SETTINGS_DIR"/products/*.json; do
      [ "$(json_nested "$pj" category url)" != "$sec_key" ] && continue
      local name=$(json_val "$pj" name)
      local url=$(json_val "$pj" url)
      items+="<li><a href='/${PRODUCTS_DIR}/${url}.html'>${name}</a></li>"
    done
    [ -n "$items" ] && html+="<h4>${sec_label}</h4><ul>${items}</ul>"
  done
  printf '%s' "$html"
}

# --- Sitemap Products: flat list ---
build_sitemap_products_flat() {
  local html="<ul>"
  for pj in "$SETTINGS_DIR"/products/*.json; do
    local name=$(json_val "$pj" name)
    local url=$(json_val "$pj" url)
    html+="<li><a href='/${PRODUCTS_DIR}/${url}.html'>${name}</a></li>"
  done
  html+="</ul>"
  printf '%s' "$html"
}

# --- Sitemap HTML Builder (E8) ---
build_sitemap_html() {
  local lbl_pages=$(json_label pages)
  local lbl_products=$(json_label products)

  local html="<h3>${lbl_pages}</h3><ul>"
  local entries=""
  for pj in "$SETTINGS_DIR"/pages/*.json; do
    local page_name=$(basename "$pj" .json)
    [ "$page_name" = "404" ] && continue
    local priority=$(json_num "$pj" priority)
    [ -z "$priority" ] && priority="0.6"
    local title=$(json_val "$pj" title)
    title=${title%% |*}
    local href=$(page_href "$page_name")
    entries+="${priority}|<li><a href='${href}'>${title}</a></li>"$'\n'
  done
  html+=$(echo "$entries" | sort -t'|' -k1 -rn | cut -d'|' -f2- | tr -d '\n')
  html+="</ul>"

  html+="<h3>${lbl_products}</h3>"
  if [ "$IS_CATEGORY_COLLAPSABLE" = "true" ]; then
    html+=$(build_sitemap_products_grouped)
  else
    html+=$(build_sitemap_products_flat)
  fi

  printf '%s' "$html"
}

# --- Sitemap XML ---
build_sitemap_xml() {
  local xml='<?xml version="1.0" encoding="UTF-8"?>'
  xml+='<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'

  local idx_priority=$(json_num "$SETTINGS_DIR/pages/index.json" priority)
  [ -z "$idx_priority" ] && idx_priority="1.0"
  xml+="<url><loc>${SITE_DOMAIN}/</loc><priority>${idx_priority}</priority></url>"

  local entries=""
  for pj in "$SETTINGS_DIR"/pages/*.json; do
    local name=$(basename "$pj" .json)
    [ "$name" = "404" ] || [ "$name" = "index" ] && continue
    local priority=$(json_num "$pj" priority)
    [ -z "$priority" ] && priority="0.6"
    entries+="${priority}|<url><loc>${SITE_DOMAIN}/${PAGES_DIR}/${name}.html</loc><priority>${priority}</priority></url>"$'\n'
  done
  xml+=$(echo "$entries" | sort -t'|' -k1 -rn | cut -d'|' -f2-)

  for pj in "$SETTINGS_DIR"/products/*.json; do
    local url=$(json_val "$pj" url)
    xml+="<url><loc>${SITE_DOMAIN}/${PRODUCTS_DIR}/${url}.html</loc><priority>0.8</priority></url>"
  done

  xml+='</urlset>'
  printf '%s' "$xml" > "$OUTPUT_DIR/sitemap.xml"
  echo "sitemap.xml built"
}

# --- Footer Builder ---
build_footer() {
  local lang_nav="$1"
  local tpl=$(<"$TEMPLATE_DIR/partials/footer.html")
  local phone=$(json_val "$COMPANY_JSON" phone)
  local email=$(json_val "$COMPANY_JSON" email)
  local phone_cleaned=$(echo "$phone" | tr -d '+ ')

  local addr="" in_addr=0
  while IFS= read -r line; do
    [[ "$line" == *'"address"'* ]] && { in_addr=1; continue; }
    [ $in_addr -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
    [ -n "$v" ] && { [ -n "$addr" ] && addr+="<br>"; addr+="$v"; }
  done < "$COMPANY_JSON"

  render_template "$tpl" \
    "slogan"        "$L_SLOGAN" \
    "lbl_adress"    "$(json_label address)" \
    "adress_lines"  "$addr" \
    "phone_cleaned" "$phone_cleaned" \
    "lbl_phone"     "$(json_label phone)" \
    "phone"         "$phone" \
    "lbl_email"     "$(json_label email)" \
    "email"         "$email" \
    "footer_nav"    "$(build_footer_link)" \
    "lang_nav"      "$lang_nav" \
    "copyright"     "${L_LEGAL} © ${L_YEAR}"
}

# --- Footer Link Builder ---
build_footer_link() {
  local html=""
  for pj in "$SETTINGS_DIR"/pages/*.json; do
    local pname=$(basename "$pj" .json)
    local short=$(json_val "$pj" title)
    short=${short%% |*}
    local href=$(page_href "$pname")
    json_flag "$pj" showOnFooter && html+="<a href=\"${href}\">${short}</a>"
  done
  [ -n "$html" ] && printf '<div class="footer-links">%s</div>' "$html"
}

# --- Init Layout (E2) ---
init_layout() {
  L_EMAIL=$(json_val "$COMPANY_JSON" email)
  L_LEGAL=$(json_val "$COMPANY_JSON" legalName)
  L_SLOGAN=$(json_val "$COMPANY_JSON" slogan)
  L_PHONE=$(json_val "$COMPANY_JSON" phone)
  L_YEAR=$(date +%Y)
  L_OFFLINE=$(json_val "$SITE_JSON" offlineWarning)
  L_BRAND=$(json_val "$COMPANY_JSON" brand)
  parse_hreflangs

  local ig=$(json_val "$COMPANY_JSON" instagram)
  local fb=$(json_val "$COMPANY_JSON" facebook)
  local ln=$(json_val "$COMPANY_JSON" linkedin)
  local wa=$(echo "$L_PHONE" | tr -d '+ ')

  L_SOCIAL=""
  [ "$ig" != "#" ] && L_SOCIAL+="<a href=\"${ig}\" target=\"_blank\"><img src=\"/img/instagram.png\" alt=\"Instagram\"></a>"
  [ "$fb" != "#" ] && L_SOCIAL+="<a href=\"${fb}\" target=\"_blank\"><img src=\"/img/facebook.png\" alt=\"Facebook\"></a>"
  [ "$ln" != "#" ] && L_SOCIAL+="<a href=\"${ln}\" target=\"_blank\"><img src=\"/img/linkedin.png\" alt=\"LinkedIn\"></a>"
  [ -n "$wa" ] && L_SOCIAL+="<a href=\"https://wa.me/${wa}\" target=\"_blank\"><img src=\"/img/whatsapp.png\" alt=\"WhatsApp\"></a>"

  L_MNAMES=()
  L_MSHORTS=()
  for pj in "$SETTINGS_DIR"/pages/*.json; do
    local pname=$(basename "$pj" .json)
    local short=$(json_val "$pj" title)
    short=${short%% |*}
    json_flag "$pj" showOnHeaderMenu && { L_MNAMES+=("$pname"); L_MSHORTS+=("$short"); }
  done

}

# --- Language Nav Builder ---
build_lang_nav() {
  local path="$1"
  local html="" in_switch=0
  local label="" url="" code=""

  while IFS= read -r line; do
    [[ "$line" == *'"langSwitch"'* ]] && { in_switch=1; continue; }
    [ $in_switch -eq 0 ] && continue
    [[ "$line" =~ ^[[:space:]]*\] ]] && break

    local l=$(echo "$line" | sed -n 's/.*"label"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    local u=$(echo "$line" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    local c=$(echo "$line" | sed -n 's/.*"lang"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    [ -n "$l" ] && label="$l"
    [ -n "$u" ] && url="$u"
    [ -n "$c" ] && code="$c"

    if [[ "$line" == *"}"* ]] && [ -n "$label" ]; then
      if [ "$code" = "$SITE_LANG" ]; then
        html+="<b>${label}</b>"
      else
        html+="<a href=\"${url}${path}\" hreflang=\"${code}\">${label}</a>"
      fi
      label="" url="" code=""
    fi
  done < "$SITE_JSON"

  [ -n "$html" ] && printf '<span class="lang">%s</span>' "$html"
}

# --- SEO Helpers (canonical + hreflang) ---
parse_hreflangs() {
  L_HREFLANGS=""
  local in_switch=0
  local url="" code=""

  while IFS= read -r line; do
    [[ "$line" == *'"langSwitch"'* ]] && { in_switch=1; continue; }
    [ $in_switch -eq 0 ] && continue
    [[ "$line" =~ ^[[:space:]]*\] ]] && break

    local u=$(echo "$line" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    local c=$(echo "$line" | sed -n 's/.*"lang"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    [ -n "$u" ] && url="$u"
    [ -n "$c" ] && code="$c"

    if [[ "$line" == *"}"* ]] && [ -n "$code" ] && [ -n "$url" ]; then
      [ -n "$L_HREFLANGS" ] && L_HREFLANGS+=" "
      L_HREFLANGS+="${code}|${url}"
      url="" code=""
    fi
  done < "$SITE_JSON"
}

build_seo_tags() {
  local path="$1"
  local canonical="${SITE_DOMAIN}${path}"
  local html=""
  for entry in $L_HREFLANGS; do
    local lang="${entry%%|*}"
    local domain="${entry#*|}"
    html+="<link rel=\"alternate\" hreflang=\"${lang}\" href=\"${domain}${path}\">"
  done
  printf '%s' "$html"
}

# --- Header Menu Builder (E3) ---
build_hmenu() {
  [ ${#L_MNAMES[@]} -eq 0 ] && return

  local active="$1" links=""
  for i in "${!L_MNAMES[@]}"; do
    local href=$(page_href "${L_MNAMES[$i]}")
    if [ "${L_MNAMES[$i]}" = "$active" ]; then
      links+="<a href=\"${href}\" class=\"active\">${L_MSHORTS[$i]}</a>"
    else
      links+="<a href=\"${href}\">${L_MSHORTS[$i]}</a>"
    fi
  done
  printf '<nav><div>%s</div></nav>' "$links"
}

# --- Hero Builder (H4, H5) ---
build_hero() {
  local data_key="$1"
  local hero_img=$(json_nested "$SITE_JSON" "$data_key" img)
  local hero_link=$(json_nested "$SITE_JSON" "$data_key" link)
  local hero_btn=$(json_nested "$SITE_JSON" "$data_key" link_text)
  local hero_lazy=""
  json_flag "$SITE_JSON" "$data_key" 2>/dev/null
  # Check lazy flag within the hero object
  local lazy_check=$(sed -n '/"'"$data_key"'"/,/}/p' "$SITE_JSON" | grep -c '"lazy"[[:space:]]*:[[:space:]]*true')
  [ "$lazy_check" -gt 0 ] && hero_lazy="1"

  # Parse text array
  local hero_line1="" hero_line2=""
  local text_idx=0
  while IFS= read -r v || [ -n "$v" ]; do
    [ -z "$v" ] && continue
    [ $text_idx -eq 0 ] && hero_line1="$v"
    [ $text_idx -eq 1 ] && hero_line2="$v"
    text_idx=$((text_idx + 1))
  done < <(json_nested_array "$SITE_JSON" "$data_key" text)

  # Build img tag based on lazy flag (H4)
  local img_tag
  if [ "$hero_lazy" = "1" ]; then
    img_tag="<img src=\"$(blur_src "/img/pages/$hero_img")\" data-src=\"/img/pages/$hero_img\" loading=\"lazy\" alt=\"${hero_line1}\">"
  else
    img_tag="<img src=\"/img/pages/$hero_img\" alt=\"${hero_line1}\">"
  fi

  local tpl
  tpl=$(<"$TEMPLATE_DIR/partials/hero.html")
  render_template "$tpl" \
    "hero_img_tag" "$img_tag" \
    "hero_line1" "$hero_line1" \
    "hero_line2" "$hero_line2" \
    "hero_link" "$hero_link" \
    "hero_btn" "$hero_btn"
}

# --- Partial Renderer ---
render_partial() {
  local partial_spec="$1" page_json="$2"
  local name="${partial_spec%%:*}"
  local data_key="${partial_spec#*:}"
  [ "$data_key" = "$name" ] && data_key=""

  case "$name" in
    hero)
      build_hero "$data_key"
      ;;
    contact)
      build_contact
      ;;
    product-cards)
      build_product_cards
      ;;
    sitemap-list)
      build_sitemap_html
      ;;
    article-header)
      # H3: isAllProductsPage uses h4 + slogan, others use h2 + short title
      local heading_tag="h2"
      local page_heading
      if json_flag "$page_json" isAllProductsPage; then
        heading_tag="h4"
        page_heading="$L_SLOGAN"
      else
        local ptitle=$(json_val "$page_json" title)
        page_heading="${ptitle%% |*}"
      fi
      printf '<article><%s>%s</%s>' "$heading_tag" "$page_heading" "$heading_tag"
      ;;
    page-image)
      # E11: Only render if image file exists
      local pname=$(basename "$page_json" .json)
      if [ -f "$OUTPUT_DIR/img/pages/${pname}.webp" ]; then
        local tpl
        tpl=$(<"$TEMPLATE_DIR/partials/page-image.html")
        local ptitle=$(json_val "$page_json" title)
        local pshort="${ptitle%% |*}"
        render_template "$tpl" \
          "name" "$pname" \
          "page_heading" "$pshort"
      fi
      ;;
    parts)
      build_main "$page_json"
      ;;
    article-footer)
      printf '</article>'
      ;;
    *)
      local tpl_file="$TEMPLATE_DIR/partials/${name}.html"
      [ -f "$tpl_file" ] && cat "$tpl_file"
      ;;
  esac
}

# --- Build Main Content from Partials ---
build_main_content() {
  local page_json="$1"
  local html=""
  local partials=$(sed -n 's/.*"partials"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' "$page_json")

  if [ -z "$partials" ]; then
    return
  fi

  IFS=',' read -ra part_arr <<< "$partials"
  for p in "${part_arr[@]}"; do
    p=$(echo "$p" | tr -d '"[:space:]')
    html+=$(render_partial "$p" "$page_json")
  done
  printf '%s' "$html"
}

# --- Single product card <li> ---
build_product_card_item() {
  local pj="$1"
  local add_to_basket="$2"
  local name=$(json_val "$pj" name)
  local url=$(json_val "$pj" url)
  local price=$(json_num "$pj" price)
  local short_desc=$(json_val "$pj" shortDesc)
  local img=$(json_img "$pj")
  local product_id=$(json_val "$pj" id)
  local html="<li>"
  html+="<a href=\"/${PRODUCTS_DIR}/${url}.html\">"
  html+="<img src=\"/img/products/$(blur_src "$img")\" data-src=\"/img/products/${img}\" loading=\"lazy\" alt=\"${L_BRAND} ${name}\" title=\"${L_BRAND} ${name}\">"
  html+="<h3>${name}</h3></a>"
  html+="<p>${short_desc}</p>"
  html+="<b>${price} ${SITE_CURRENCY_SYMBOL}</b>"
  html+="<button data-id=\"${product_id}\">${add_to_basket}</button>"
  html+="</li>"
  printf '%s' "$html"
}

# --- Product cards grouped by category ---
build_product_cards_grouped() {
  local add_to_basket=$(json_label addToBasket)
  local html=""
  for section in "${PRODUCT_SECTIONS[@]}"; do
    IFS='|' read -r sec_key sec_label <<< "$section"
    local section_entries="" section_html=""
    for pj in "$SETTINGS_DIR"/products/*.json; do
      [ "$(json_nested "$pj" category url)" != "$sec_key" ] && continue
      local product_id=$(json_val "$pj" id)
      local sort_order="${product_id//[^0-9]/}"
      [ -z "$sort_order" ] && sort_order=99
      section_entries+="${sort_order}|${pj}"$'\n'
    done
    while IFS='|' read -r _order product_path; do
      [ -z "$product_path" ] && continue
      section_html+=$(build_product_card_item "$product_path" "$add_to_basket")
    done < <(printf '%s' "$section_entries" | sort -t'|' -k1 -n)
    if [ -n "$section_html" ]; then
      html+="<details open>"
      html+="<summary>${sec_label}</summary>"
      html+="<ul class=\"prd\">${section_html}</ul>"
      html+="</details>"
    fi
  done
  printf '%s' "$html"
}

# --- Product cards flat list ---
build_product_cards_flat() {
  local add_to_basket=$(json_label addToBasket)
  local html="<ul class=\"prd\">"
  for pj in "$SETTINGS_DIR"/products/*.json; do
    html+=$(build_product_card_item "$pj" "$add_to_basket")
  done
  html+="</ul>"
  printf '%s' "$html"
}

# --- Product Cards Builder — dispatcher (E12) ---
build_product_cards() {
  if [ "$IS_CATEGORY_COLLAPSABLE" = "true" ]; then
    build_product_cards_grouped
  else
    build_product_cards_flat
  fi
}

# --- Tabs Builder ---
build_tabs() {
  local pj="$1"
  local lbl_desc=$(json_label productDescTab)
  local lbl_specs=$(json_label productSpecsTab)

  local html='<input type="radio" id="tab-desc" name="ptab" checked>'
  html+='<input type="radio" id="tab-specs" name="ptab">'
  html+="<div class=\"tab-nav\"><label for=\"tab-desc\">${lbl_desc}</label><label for=\"tab-specs\">${lbl_specs}</label></div>"

  # Tab 1: longDesc paragraphs
  html+='<div class="tab-desc">'
  local in_long=0
  while IFS= read -r line; do
    [[ "$line" == *'"longDesc"'* ]] && { in_long=1; continue; }
    [ $in_long -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
    [ -n "$v" ] && html+="<p>${v}</p>"
  done < "$pj"
  html+='</div>'

  # Tab 2: otherDesc table
  html+='<div class="tab-specs"><table>'
  local in_other=0
  while IFS= read -r line; do
    [[ "$line" == *'"otherDesc"'* ]] && { in_other=1; continue; }
    [ $in_other -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local n=$(echo "$line" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    local v=$(echo "$line" | sed -n 's/.*"value"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -n "$n" ] && html+="<tr><th>${n}</th><td>${v}</td></tr>"
  done < "$pj"
  html+='</table></div>'

  printf '%s' "$html"
}

# --- Additional Properties for Schema ---
build_add_props() {
  local props="" first=1
  while IFS= read -r line; do
    local n=$(echo "$line" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    local v=$(echo "$line" | sed -n 's/.*"value"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
    [ -z "$n" ] && continue
    [ $first -eq 0 ] && props+=","
    props+="{\"@type\":\"PropertyValue\",\"name\":\"${n}\",\"value\":\"${v}\"}"
    first=0
  done < <(sed -n '/"otherDesc"/,/\]/p' "$1" | grep '"name"')
  printf '%s' "$props"
}

# --- Schema Builder ---
build_schema() {
  local pj="$1"

  local id=$(json_val "$pj" id)
  local name=$(json_val "$pj" name)
  local desc=$(json_val "$pj" metaDesc)
  local url=$(json_val "$pj" url)
  local keys=$(json_val "$pj" keywords)
  local price=$(json_num "$pj" price)
  local img=$(json_img "$pj")
  local wval=$(sed -n 's/.*"weight".*"value"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$pj")

  local brand=$(json_val "$pj" brand)
  [ -z "$brand" ] && brand=$(json_val "$COMPANY_JSON" brand)

  local currency=$(json_val "$pj" currency)
  [ -z "$currency" ] && currency=$(json_val "$COMPANY_JSON" currency)

  local pvdays=$(json_num "$pj" priceValidUntilDays)
  [ -z "$pvdays" ] && pvdays=$(json_num "$COMPANY_JSON" priceValidUntilDays)
  [ -z "$pvdays" ] && pvdays=180
  local valid_until=$(date -d "+${pvdays} days" +%Y-%m-%d)

  local mfr_name=$(json_nested "$pj" manufacturer name)
  [ -z "$mfr_name" ] && mfr_name=$(json_nested "$COMPANY_JSON" manufacturer name)
  local mfr_id=$(json_nested "$pj" manufacturer identifier)
  [ -z "$mfr_id" ] && mfr_id=$(json_nested "$COMPANY_JSON" manufacturer identifier)
  local mfr_phone=$(json_nested "$pj" manufacturer phone)
  [ -z "$mfr_phone" ] && mfr_phone=$(json_nested "$COMPANY_JSON" manufacturer phone)
  local mfr_addr=$(json_nested "$pj" manufacturer address)
  [ -z "$mfr_addr" ] && mfr_addr=$(json_nested "$COMPANY_JSON" manufacturer address)
  local mfr_city=$(json_nested "$pj" manufacturer city)
  [ -z "$mfr_city" ] && mfr_city=$(json_nested "$COMPANY_JSON" manufacturer city)
  local mfr_country=$(json_nested "$pj" manufacturer country)
  [ -z "$mfr_country" ] && mfr_country=$(json_nested "$COMPANY_JSON" manufacturer country)

  # Strip domain protocol for schema URLs (matches original: "ozumle.com/products/...")
  local schema_domain="${SITE_DOMAIN#https://}"
  schema_domain="${schema_domain#http://}"

  local s='{"@context":"https://schema.org/","@type":"Product"'
  s+=',"name":"'"${brand} ${name}"'"'
  s+=',"productID":"'"${id}"'"'
  s+=',"description":"'"${desc}"'"'
  s+=',"url":"'"${schema_domain}/${PRODUCTS_DIR}/${url}"'.html"'
  s+=',"image":"'"${schema_domain}/images/${img}"'"'
  s+=',"brand":{"@type":"Brand","name":"'"${brand}"'"}'
  s+=',"manufacturer":{"@type":"Organization","name":"'"${mfr_name}"'","identifier":"'"${mfr_id}"'"'
  s+=',"contactPoint":{"@type":"ContactPoint","telephone":"'"${mfr_phone}"'","contactType":"customer service"}'
  s+=',"address":{"@type":"PostalAddress","streetAddress":"'"${mfr_addr}"'","addressLocality":"'"${mfr_city}"'","addressCountry":"'"${mfr_country}"'"}}'
  s+=',"keywords":"'"${keys}"'"'
  [ -n "$wval" ] && s+=',"weight":{"@type":"QuantitativeValue","value":'"${wval}"',"unitCode":"GRM"}'

  local add_props=$(build_add_props "$pj")
  [ -n "$add_props" ] && s+=',"additionalProperty":['"${add_props}"']'

  s+=',"offers":{"@type":"Offer"'
  s+=',"url":"'"${schema_domain}/${PRODUCTS_DIR}/${url}"'.html"'
  s+=',"priceCurrency":"'"${currency}"'"'
  s+=',"price":"'"${price}"'"'
  s+=',"priceValidUntil":"'"${valid_until}"'"'
  s+=',"itemCondition":"https://schema.org/NewCondition"'
  s+=',"availability":"https://schema.org/InStock"}'

  local ar_val=$(json_nested "$pj" aggregateRating ratingValue)
  local ar_count=$(json_nested "$pj" aggregateRating reviewCount)
  if [ -n "$ar_val" ] && [ -n "$ar_count" ]; then
    local ar_best=$(json_nested "$pj" aggregateRating bestRating)
    local ar_worst=$(json_nested "$pj" aggregateRating worstRating)
    s+=',"aggregateRating":{"@type":"AggregateRating"'
    s+=',"ratingValue":"'"${ar_val}"'","reviewCount":"'"${ar_count}"'"'
    s+=',"bestRating":"'"${ar_best}"'","worstRating":"'"${ar_worst}"'"}'
  fi

  local rv_author=$(json_nested "$pj" review author)
  if [ -n "$rv_author" ]; then
    local rv_val=$(json_nested "$pj" review ratingValue)
    local rv_date=$(json_nested "$pj" review date)
    local rv_body=$(json_nested "$pj" review body)
    s+=',"review":{"@type":"Review"'
    s+=',"reviewRating":{"@type":"Rating","ratingValue":"'"${rv_val}"'"}'
    s+=',"author":{"@type":"Person","name":"'"${rv_author}"'"}'
    s+=',"datePublished":"'"${rv_date}"'"'
    s+=',"reviewBody":"'"${rv_body}"'"}'
  fi

  s+='}'
  printf '%s' "$s"
}

# --- Home Page Schema (@graph: Organization + WebSite + ItemList) ---
build_home_schema() {
  local phone=$(json_val "$COMPANY_JSON" phone)
  local tel=$(echo "$phone" | tr -d ' ')
  local email=$(json_val "$COMPANY_JSON" email)
  local legal=$(json_val "$COMPANY_JSON" legalName)
  local desc=$(json_val "$COMPANY_JSON" description)
  local brand=$(json_val "$COMPANY_JSON" brand)

  # Build address string
  local addr=""
  local in_addr=0
  while IFS= read -r line; do
    [[ "$line" == *'"address"'* ]] && { in_addr=1; continue; }
    [ $in_addr -eq 0 ] && continue
    [[ "$line" == *']'* ]] && break
    local v=$(echo "$line" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:],]*$/\1/p')
    [ -n "$v" ] && { [ -n "$addr" ] && addr+=", "; addr+="$v"; }
  done < "$COMPANY_JSON"

  # Social links
  local ig=$(json_val "$COMPANY_JSON" instagram)
  local sameAs=""
  [ -n "$ig" ] && [ "$ig" != "#" ] && sameAs+="\"${ig}\""

  local s='{"@context":"https://schema.org","@graph":['

  # Organization
  s+='{"@type":"Organization"'
  s+=',"name":"'"${legal}"'"'
  s+=',"url":"'"${SITE_DOMAIN}"'"'
  s+=',"logo":"'"${SITE_DOMAIN}/logo.png"'"'
  s+=',"description":"'"${desc}"'"'
  s+=',"brand":{"@type":"Brand","name":"'"${brand}"'"}'
  s+=',"telephone":"'"${tel}"'"'
  s+=',"email":"'"${email}"'"'
  s+=',"address":{"@type":"PostalAddress","streetAddress":"'"${addr}"'","addressCountry":"TR"}'
  [ -n "$sameAs" ] && s+=',"sameAs":['"${sameAs}"']'
  s+='}'

  # WebSite
  s+=',{"@type":"WebSite"'
  s+=',"name":"'"${brand}"'"'
  s+=',"url":"'"${SITE_DOMAIN}"'"}'

  # ItemList with Products
  s+=',{"@type":"ItemList","itemListElement":['
  local pos=0 first=1
  for pj in "$SETTINGS_DIR"/products/*.json; do
    pos=$((pos + 1))
    [ $first -eq 0 ] && s+=","
    first=0
    local ps=$(build_schema "$pj")
    ps=$(echo "$ps" | sed 's|{"@context":"https://schema.org/",|{|')
    s+='{"@type":"ListItem","position":'"${pos}"',"item":'"${ps}"'}'
  done
  s+=']}]}'

  printf '%s' "$s"
}

# --- Build Pages ---
build_pages() {
  mkdir -p "$OUTPUT_DIR/$PAGES_DIR"

  for pj in "$SETTINGS_DIR"/pages/*.json; do
    local name=$(basename "$pj" .json)
    local title=$(json_val "$pj" title)
    local desc=$(json_val "$pj" description)
    local keys=$(json_val "$pj" keywords)
    local hmenu=$(build_hmenu "$name")
    local main_html=$(build_main_content "$pj")
    local out_path=$(page_output_path "$name")

    local seo_path
    if [ "$name" = "index" ]; then seo_path="/"; else seo_path=$(page_href "$name"); fi
    local canonical="${SITE_DOMAIN}${seo_path}"
    local hreflang=$(build_seo_tags "$seo_path")
    local lang_nav=$(build_lang_nav "$seo_path")

    local extra=""
    if [ "$name" = "index" ]; then
      local schema=$(build_home_schema)
      schema=$(printf '%s' "$schema" | sed 's/&/\\&/g')
      extra=$'\n    '"<script type=\"application/ld+json\">${schema}</script>"
    fi

    apply_layout "$TEMPLATE_DIR/layout.html" \
      "lang" "$SITE_LANG" \
      "title" "$title" \
      "description" "$desc" \
      "keywords" "$keys" \
      "canonical" "$canonical" \
      "hreflang" "$hreflang" \
      "nav" "$hmenu" \
      "main" "$main_html" \
      "offline_warning" "$L_OFFLINE" \
      "slogan" "$L_SLOGAN" \
      "brand" "$L_BRAND" \
      "footer" "$(build_footer "$lang_nav")" \
      "extra_scripts" "$extra" \
      > "$out_path"
  done

  echo "pages built"
}

# --- Build Products (E6) ---
build_products() {
  local addToBasket=$(json_label addToBasket)
  local taxIncluded=$(json_val "$SITE_JSON" taxIncluded)
  local hmenu=$(build_hmenu "")

  mkdir -p "$OUTPUT_DIR/$PRODUCTS_DIR"

  local product_tpl
  product_tpl=$(<"$TEMPLATE_DIR/partials/product.html")

  for pj in "$SETTINGS_DIR"/products/*.json; do
    local id=$(json_val "$pj" id)
    local name=$(json_val "$pj" name)
    local url=$(json_val "$pj" url)
    local price=$(json_num "$pj" price)
    local desc=$(json_val "$pj" metaDesc)
    local keys=$(json_val "$pj" keywords)
    local img=$(json_img "$pj")
    local title="${L_BRAND} ${name} | ${L_BRAND}"

    local seo_path="/${PRODUCTS_DIR}/${url}.html"
    local canonical="${SITE_DOMAIN}${seo_path}"
    local hreflang=$(build_seo_tags "$seo_path")
    local lang_nav=$(build_lang_nav "$seo_path")

    local schema=$(build_schema "$pj")
    # Escape & for sed safety
    schema=$(printf '%s' "$schema" | sed 's/&/\\&/g')

    local tabs=$(build_tabs "$pj")
    tabs=$(printf '%s' "$tabs" | sed 's/&/\\&/g')

    local blur=$(blur_src "$img")

    local product_html
    product_html=$(render_template "$product_tpl" \
      "product_img" "$img" \
      "product_blur" "$blur" \
      "product_full_name" "${L_BRAND} ${name}" \
      "product_id" "$id" \
      "product_name" "$name" \
      "product_price" "$price" \
      "currency_symbol" "$SITE_CURRENCY_SYMBOL" \
      "tax_label" "$taxIncluded" \
      "add_to_basket" "$addToBasket" \
      "tabs" "$tabs")

    local schema_script=$'\n    '"<script type=\"application/ld+json\">${schema}</script>"

    apply_layout "$TEMPLATE_DIR/layout.html" \
      "lang" "$SITE_LANG" \
      "title" "$title" \
      "description" "$desc" \
      "keywords" "$keys" \
      "canonical" "$canonical" \
      "hreflang" "$hreflang" \
      "nav" "$hmenu" \
      "main" "$product_html" \
      "offline_warning" "$L_OFFLINE" \
      "slogan" "$L_SLOGAN" \
      "brand" "$L_BRAND" \
      "footer" "$(build_footer "$lang_nav")" \
      "extra_scripts" "$schema_script" \
      > "$OUTPUT_DIR/$PRODUCTS_DIR/${url}.html"
  done

  echo "products built"
}

# --- Service Worker Builder ---
build_sw() {
  local core="'/','/site.css','/site.js','/logo.png','/favicon.png','/favicon.ico'"

  local products=""
  for f in "$OUTPUT_DIR/$PRODUCTS_DIR"/*.html; do
    [ -f "$f" ] && products+=",'/${PRODUCTS_DIR}/$(basename "$f")'"
  done
  for f in "$OUTPUT_DIR"/img/products/*.webp; do
    [ -f "$f" ] && products+=",'/img/products/$(basename "$f")'"
  done
  products=${products#,}

  local pages=""
  for f in "$OUTPUT_DIR/$PAGES_DIR"/*.html; do
    [ -f "$f" ] && pages+=",'/${PAGES_DIR}/$(basename "$f")'"
  done
  pages+=",'/index.html','/404.html'"
  for f in "$OUTPUT_DIR"/img/*.png; do
    [ -f "$f" ] && pages+=",'/img/$(basename "$f")'"
  done
  for f in "$OUTPUT_DIR"/img/pages/*.webp; do
    [ -f "$f" ] && pages+=",'/img/pages/$(basename "$f")'"
  done
  pages=${pages#,}

  local version=$(date +%Y%m%d%H%M%S)

  sed \
    -e "s#__CACHE_PREFIX__#${SITE_CACHE_PREFIX}#" \
    -e "s#__CORE__#[${core}]#" \
    -e "s#__PRODUCTS__#[${products}]#" \
    -e "s#__PAGES__#[${pages}]#" \
    -e "s#__VERSION__#${version}#" \
    -e "s#'#\"#g" \
    "$TEMPLATE_DIR/js/sw.js" > "$OUTPUT_DIR/sw.js"

  echo "sw.js built"
}

# --- Product Catalog Injection (E1) ---
inject_product_catalog() {
  local js="let PRODUCTS={"
  local first=1

  for pj in "$SETTINGS_DIR"/products/*.json; do
    local id=$(json_val "$pj" id)
    local name=$(json_val "$pj" name)
    local price=$(json_num "$pj" price)
    local wval=$(sed -n 's/.*"weight".*"value"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$pj")
    local img=$(json_img "$pj")

    [ $first -eq 0 ] && js+=","
    js+="\"${id}\":{\"name\":\"${name}\",\"price\":${price},\"weight\":${wval},\"img\":\"${img}\"}"
    first=0
  done

  js+="};"
  sed -i "s#let PRODUCTS = {};#${js}#" "$OUTPUT_DIR/site.js"
  echo "product catalog injected"
}

# --- Basket Config Injection ---
inject_basket_config() {
  local warning=$(json_val "$SITE_JSON" basketWarning)
  local wa_warning=$(json_val "$SITE_JSON" whatsAppWarning)
  local shipping_warning=$(json_val "$SITE_JSON" shippingWarning)
  local wa_number=$(echo "$(json_val "$COMPANY_JSON" phone)" | tr -d '+ ')

  local products_page=$(json_val "$SITE_JSON" productsPage)
  [ -z "$products_page" ] && products_page="/${PAGES_DIR}/urunlerimiz.html"

  local js="let BASKET_CONFIG={"
  js+="\"warning\":\"${warning}\""
  js+=",\"waWarning\":\"${wa_warning}\""
  js+=",\"shippingWarning\":\"${shipping_warning}\""
  js+=",\"currency\":\"${SITE_CURRENCY_SYMBOL}\""
  js+=",\"waNumber\":\"${wa_number}\""
  js+=",\"productsPage\":\"${products_page}\""

  # Build labels object
  js+=",\"labels\":{"
  local first=1
  local label_keys="addToBasket basket myBasket itemSuffix for openBasket closeBasket subtotal shipping freeShipping total delete unit whatsAppOrder whatsAppGreeting emptyBasket productsLinkText emptyBasketDesc"
  for k in $label_keys; do
    local v=$(json_label "$k")
    if [ -n "$v" ]; then
      [ $first -eq 0 ] && js+=","
      js+="\"${k}\":\"${v}\""
      first=0
    fi
  done
  js+="}}"

  sed -i "s#let BASKET_CONFIG = {};#${js};#" "$OUTPUT_DIR/site.js"
  echo "basket config injected"
}

# ============================================
# MAIN EXECUTION (E5: preserved order)
# ============================================

bash "$TEMPLATE_DIR/process-template.sh" "$TEMPLATE_DIR" "$SETTINGS_DIR" "$OUTPUT_DIR"
inject_product_catalog
inject_basket_config
init_layout
build_pages
build_products
build_sitemap_xml
build_sw
