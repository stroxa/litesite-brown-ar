function parseLocalizedNumber(str) {
  if (!str) { return 0; }
  let normalized = str.replace(/[٠-٩]/g, function(d) {
    return '٠١٢٣٤٥٦٧٨٩'.indexOf(d);
  });
  let num = parseFloat(normalized.replace(/[^0-9.]/g, ''));
  return isNaN(num) ? 0 : num;
}
