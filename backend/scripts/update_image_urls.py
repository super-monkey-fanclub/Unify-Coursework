import sqlite3
from pathlib import Path
DB = Path(__file__).resolve().parents[1] / 'db.sqlite3'
if not DB.exists():
    print('DB not found', DB)
    raise SystemExit(1)
conn = sqlite3.connect(str(DB))
cur = conn.cursor()
mapping = {
    'art society': 'https://images.unsplash.com/photo-1579783902614-a3fb3927b6a5?w=800&auto=format&fit=crop',
    'anime society': 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&auto=format&fit=crop',
    'gaming society': 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=800&auto=format&fit=crop',
    'music society': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop',
    'photography club': 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&auto=format&fit=crop',
    'dance society': 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=800&auto=format&fit=crop',
    'drama club': 'https://plus.unsplash.com/premium_photo-1684923604128-c48f46b0cb00?q=80&w=1471&auto=format&fit=crop',
    'coding society': 'https://images.unsplash.com/photo-1461749280684-dccba630e2f6?w=800&auto=format&fit=crop',
    'robotics club': 'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800&auto=format&fit=crop',
    'chess club': 'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=800&auto=format&fit=crop',
    'film society': 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?w=800&auto=format&fit=crop',
    'environmental club': 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=800&auto=format&fit=crop',
    'entrepreneurship society': 'https://images.unsplash.com/photo-1496307042754-b4aa456c4a2d?w=800&auto=format&fit=crop',
    'cooking society': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800&auto=format&fit=crop',
}
updated = 0
for name, url in mapping.items():
    cur.execute("UPDATE core_society SET image_url=? WHERE lower(name)=?", (url, name))
    updated += cur.rowcount
conn.commit()
print('Total rows updated:', updated)
for r in cur.execute("select id,name,image_url from core_society order by id"): 
    print(r)
conn.close()
