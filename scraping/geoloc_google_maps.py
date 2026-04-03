import json
import time
import re
import urllib.parse
from playwright.sync_api import sync_playwright

def valider_coordonnees(lat, lng):
    if lat is None or lng is None:
        return False
    # Le Togo est situé grossièrement entre :
    # Lat: 6.0 à 11.5
    # Lng: -0.5 à 2.0
    return (6.0 <= float(lat) <= 11.5) and (-0.5 <= float(lng) <= 2.0)

def main():
    fichier_json = 'pharmacies_goafrica.json'
    
    with open(fichier_json, 'r', encoding='utf-8') as f:
        pharmacies = json.load(f)

    LAT_GENERIQUE = 6.1256983
    LNG_GENERIQUE = 1.22536

    with sync_playwright() as p:
        # On peut laisser headless=True car naviguer directement vers les URLs est plus stable
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(locale="fr-FR", permissions=["geolocation"], geolocation={"longitude": 1.2222, "latitude": 6.1319})
        page = context.new_page()
        print("Lancement de la géolocalisation...")
        
        compteur = 0

        for idx, pharma in enumerate(pharmacies):
            lat_actuelle = pharma.get("latitude")
            lng_actuelle = pharma.get("longitude")
            
            a_analyser = False
            if not valider_coordonnees(lat_actuelle, lng_actuelle):
                a_analyser = True
            elif abs(float(lat_actuelle) - LAT_GENERIQUE) < 0.001 and abs(float(lng_actuelle) - LNG_GENERIQUE) < 0.001:
                a_analyser = True
            elif abs(float(lat_actuelle) - 6.132) < 0.01 and abs(float(lng_actuelle) - 1.0) < 0.01:
                a_analyser = True
                
            if not a_analyser:
                continue
                
            nom = pharma["nom"]
            ville = "Togo"
            if "Lomé" in pharma.get("adresse", ""):
                ville = "Lomé, Togo"
            elif "Kara" in pharma.get("adresse", ""):
                ville = "Kara, Togo"
            elif "Atakpamé" in pharma.get("adresse", ""):
                ville = "Atakpamé, Togo"

            search_query = f"{nom} {ville}"
            print(f"[{idx+1}/{len(pharmacies)}] Recherche de : {search_query}")
            
            try:
                # Naviguer directement vers l'URL de recherche Google Maps
                encoded_query = urllib.parse.quote_plus(search_query)
                search_url = f"https://www.google.com/maps/search/{encoded_query}"
                
                page.goto(search_url)
                
                # Attendre que la page se stabilise (redirection vers le lieu ou affichage des résultats)
                page.wait_for_timeout(4000)
                
                # S'il y a une liste de résultats, cliquons sur le premier pour être sûr d'avoir ses coordonnées
                try:
                    page.locator('a.hfpxzc').first.click(timeout=2000)
                    page.wait_for_timeout(2000)
                except Exception:
                    pass
                
                url = page.url
                match = re.search(r'@([-\d\.]+),([-\d\.]+)', url)
                
                if match:
                    n_lat = float(match.group(1))
                    n_lng = float(match.group(2))
                    
                    if valider_coordonnees(n_lat, n_lng):
                        pharmacies[idx]["latitude"] = n_lat
                        pharmacies[idx]["longitude"] = n_lng
                        print(f"   -> Trouvé : {n_lat}, {n_lng}")
                        compteur += 1
                        
                        # Sauvegarde incrémentale
                        with open(fichier_json, 'w', encoding='utf-8') as f:
                            json.dump(pharmacies, f, ensure_ascii=False, indent=4)
                    else:
                        print(f"   -> Hors limites Togo : {n_lat}, {n_lng}")
                else:
                    print("   -> Coordonnées introuvables dans l'URL.")
                
            except Exception as e:
                print(f"   -> Erreur: {e}")

        browser.close()
        print(f"\nTerminé ! {compteur} pharmacies ont été localisées avec précision.")

if __name__ == "__main__":
    main()
