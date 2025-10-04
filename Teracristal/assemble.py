import os
import math
from PIL import Image

# dossier où se trouvent tes images
img_dir = "./"  

# récupérer toutes les images teracristal sauf stellar
images = [f for f in os.listdir(img_dir) if f.startswith("teracristal_") and f.endswith(".png") and "stellar" not in f]
images.sort()  # pour garder un ordre stable

# ajouter stellar séparément
stellar_file = "teracristal_stellar.png"

# ouvrir toutes les images (hors stellar)
imgs = [Image.open(os.path.join(img_dir, f)).convert("RGBA") for f in images]
stellar_img = Image.open(os.path.join(img_dir, stellar_file)).convert("RGBA")

# dimensions d'une carte (supposons qu'elles soient toutes identiques)
w, h = imgs[0].size

# organisation en planche :
# - 18 cartes → 3 lignes de 6
cols = 6
rows = 3
grid_w = cols * w
grid_h = rows * h + h  # +1 ligne pour Stellar

# créer la planche vide
sheet = Image.new("RGBA", (grid_w, grid_h), (255, 255, 255, 0))

# placer les 18 cartes en grille
for idx, img in enumerate(imgs):
    x = (idx % cols) * w
    y = (idx // cols) * h
    sheet.paste(img, (x, y))

# placer Stellar au centre de la dernière ligne
stellar_x = (grid_w - w) // 2
stellar_y = rows * h
sheet.paste(stellar_img, (stellar_x, stellar_y), stellar_img)

# sauvegarde
sheet.save("_teracristal_planche.png")
print("✅ Planche générée : teracristal_planche.png")
