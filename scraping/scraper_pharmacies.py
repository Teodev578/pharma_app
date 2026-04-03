from playwright.sync_api import sync_playwright
from bs4 import BeautifulSoup
import json
import time

def scraper_pharmacies_togo():
    base_url = "https://www.pharmaciens.tg/our-registry/pharmacies?page="
    toutes_les_pharmacies = []
    
    # Il y a environ 11 pages (ou jusqu'à 31 selon le site)
    nombre_de_pages = 11 
    
    print("Début du scraping avec simulation d'un vrai navigateur (Playwright)...")

    with sync_playwright() as p:
        # Lancement de Chromium en mode invisible (headless)
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        for page_num in range(1, nombre_de_pages + 1):
            url = f"{base_url}{page_num}"
            print(f"Scraping de la page {page_num}/{nombre_de_pages} : {url}")
            
            try:
                # On va sur la page avec un timeout de 60s car le site peut être lent
                page.goto(url, wait_until="domcontentloaded", timeout=60000)
                
                # On attend explicitement que la première pharmacie apparaisse sur l'écran
                page.wait_for_selector('.pharmacy-name', timeout=30000)
                
                # Une fois la page construite par React, on capture tout le code HTML !
                html_code = page.content()
                soup = BeautifulSoup(html_code, 'html.parser')
                
                # === NOUVELLE MÉTHODE PAR CARTE (PLUS FIABLE) ===
                # L'utilisateur nous a précisé les classes 'pharmacy-grid-item' ou 'modern-pharmacy-card'
                cartes = soup.find_all(class_=['pharmacy-grid-item', 'modern-pharmacy-card'])

                for carte in cartes:
                    # À l'intérieur de CHAQUE carte, on cherche le nom et la description
                    nom_elem = carte.find('h5', class_='pharmacy-name')
                    # On utilise pharmacy-description0 comme précisé par l'utilisateur
                    desc_elem = carte.find('p', class_='pharmacy-description0')
                    
                    # Fallback au cas où c'est juste pharmacy-description
                    if not desc_elem:
                        desc_elem = carte.find('p', class_='pharmacy-description')

                    # Récupération du numéro de téléphone dans "social-link phone"
                    # En cherchant class_='phone', on trouve "social-link phone" très facilement
                    tel_elem = carte.find(class_='phone')

                    nom_texte = nom_elem.text.strip() if nom_elem else "Nom inconnu"
                    desc_texte = desc_elem.text.strip() if desc_elem else "Non renseigné"
                    tel_texte = tel_elem.text.strip() if tel_elem else "Non renseigné"

                    pharmacie = {
                        "nom": nom_texte,
                        "description": desc_texte,
                        "telephone": tel_texte,
                        "est_de_garde": False
                    }
                    
                    toutes_les_pharmacies.append(pharmacie)

                # Petite pause
                time.sleep(1)

            except Exception as e:
                print(f"Avertissement (Page {page_num}): {e}")

        browser.close()

    # Sauvegarder les résultats dans un fichier JSON
    with open('pharmacies_togo.json', 'w', encoding='utf-8') as f:
        json.dump(toutes_les_pharmacies, f, ensure_ascii=False, indent=4)

    print(f"\nTerminé ! {len(toutes_les_pharmacies)} pharmacies ont été trouvées via BeautifulSoup et Playwright.")

if __name__ == "__main__":
    scraper_pharmacies_togo()