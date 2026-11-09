# 用法：python make_images_js.py 你的檔案.csv（或 .xlsx）
# 讀取「id」與「圖片網址」兩欄，產生 product-images.js
import sys, csv, json, zipfile

def read_rows(path):
    if zipfile.is_zipfile(path):                      # Excel 檔（即使副檔名是 .csv）
        import openpyxl, shutil, tempfile, os
        tmp = os.path.join(tempfile.mkdtemp(), 'x.xlsx'); shutil.copy(path, tmp)   # openpyxl 只認 .xlsx 副檔名
        return [list(r) for r in openpyxl.load_workbook(tmp, read_only=True).active.iter_rows(values_only=True)]
    for enc in ('utf-8-sig', 'cp950', 'gb18030'):     # 一般 CSV：試幾種編碼
        try:
            return list(csv.reader(open(path, encoding=enc)))
        except UnicodeDecodeError:
            pass
    sys.exit('無法讀取檔案編碼')

rows = read_rows(sys.argv[1] if len(sys.argv) > 1 else 'product-image-targets.csv')
m, bad = {}, []
for r in rows[1:]:
    if not r or r[0] in (None, ''): continue
    url = str(r[4]).strip() if len(r) > 4 and r[4] else ''
    if not url: continue
    if not url.lower().startswith('https://'):
        bad.append((r[0], url)); continue
    m[int(r[0])] = url

body = ',\n'.join(f'  {k}: {json.dumps(v)}' for k, v in sorted(m.items()))
open('product-images.js', 'w', encoding='utf-8').write(
    '// 商品編號 → 圖片網址。優先順序：賣家後台上傳 > 這份對照表 > 預設圖示\n'
    'window.MEOW_IMGS = {\n' + body + '\n};\n')
print(f'完成：{len(m)} 項已寫入 product-images.js')
for i, u in bad: print(f'略過 id {i}：網址必須以 https:// 開頭（{u[:40]}）')
