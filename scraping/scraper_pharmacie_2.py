from bs4 import BeautifulSoup
import requests
import json
import base64
import time
import re

def extraire_horaires(bouton):
    for attr_name, attr_value in bouton.attrs.items():
        if isinstance(attr_value, str) and 'popoverClass' in attr_value:
            try:
                data = json.loads(attr_value)
                content_html = data.get('content', '')
                content_soup = BeautifulSoup(content_html, 'html.parser')
                rows = content_soup.find_all('tr')
                horaires = []
                for row in rows:
                    cols = row.find_all('td')
                    if len(cols) >= 2:
                        jour = ' '.join(cols[0].text.split())
                        heure = ' '.join(cols[1].text.split())
                        horaires.append({
                            "jour": jour,
                            "heure": heure
                        })
                return horaires
            except Exception:
                pass
    return []

def scraper_goafricaonline():
    base_url = "https://www.goafricaonline.com/tg/annuaire/pharmacies"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
    }
    
    toutes_les_pharmacies = []
    noms_vus = set() # Pour éviter les doublons
    page_num = 1
    max_pages = 50 # Limite de sécurité augmentée

    print("Début du scraping sur GoAfricaOnline...")

    while page_num <= max_pages:
        # La plupart des sites utilisent ?p= ou ?page= pour la pagination
        # GoAfricaOnline utilise souvent ?p=
        url = f"{base_url}?p={page_num}" if page_num > 1 else base_url
        print(f"Scraping de la page {page_num} : {url}")
        
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            print(f"Erreur HTTP {response.status_code}. Arrêt de la pagination.")
            break
            
        soup = BeautifulSoup(response.text, 'html.parser')
        elements = soup.find_all(lambda tag: tag.has_attr('class') and 'flex' in tag.get('class') and 'w-full' in tag.get('class'))
        
        if not elements:
            print("Plus aucune pharmacie trouvée sur cette page. Fin du scraping.")
            break
            
        print(f"  -> {len(elements)} pharmacies trouvées sur cette page.")
        
        nouveaux_elements_page = 0
        
        for el in elements:
            # Texte brut global
            text_brut = ' '.join(el.text.split())
            
            # Nom
            nom_tag = el.find('a', class_=lambda c: c and 'text-' in c)
            if not nom_tag:
                 nom_tag = el.find(['h2','h3','h4'])
            nom = nom_tag.text.strip() if nom_tag else "Nom inconnu"
            
            # Ne pas enregistrer les pharmacies sans nom défini
            if nom == "Nom inconnu" or not nom:
                continue
                
            # Éviter absolument d'enregistrer des doublons (si le site boucle sur la page 1)
            if nom in noms_vus:
                continue
                
            noms_vus.add(nom)
            nouveaux_elements_page += 1
            
            # Téléphone : on cherche un tag a avec href="tel:..."
            tel_tag = el.find('a', href=lambda href: href and href.startswith('tel:'))
            telephone = tel_tag['href'].replace('tel:', '').strip() if tel_tag else ""
            
            # Si le téléphone n'est pas trouvé dans un lien cliquable, on essaie via le texte brut
            if not telephone:
                match_tel = re.search(r'Tel\s*:\s*([\+\d\s\(\)]+)', text_brut)
                if match_tel:
                    telephone = match_tel.group(1).strip()
            
            # Horaires et Statut
            btn_horaires = el.find(lambda tag: tag.has_attr('class') and ('bg-green-100' in tag.get('class') or 'bg-red-100' in tag.get('class') or 'bg-gray-100' in tag.get('class')))
            statut = btn_horaires.text.strip().split()[0] if btn_horaires else "Inconnu"
            horaires = extraire_horaires(btn_horaires) if btn_horaires else []
            
            # Adresse (via la classe flex flex-auto)
            adresse_tag = el.find(lambda tag: tag.has_attr('class') and 'flex' in tag.get('class') and 'flex-auto' in tag.get('class'))
            adresse = ""
            if adresse_tag:
                # Nettoyer et conserver les sauts de ligne pour un beau formatage
                adresse = '\n'.join([ligne.strip() for ligne in adresse_tag.text.splitlines() if ligne.strip()])

            # Lien Itinéraire Google Maps
            lien_map = el.find(lambda tag: tag.has_attr('class') and 'reset-button' in tag.get('class') and 'group' in tag.get('class'))
            url_map = ""
            latitude = None
            longitude = None
            if lien_map and lien_map.has_attr('data-cypher-link'):
                cypher = lien_map['data-cypher-link']
                try:
                    if '_goafrica_' in cypher:
                        cypher_part = cypher.split('_goafrica_')[1]
                        url_map = base64.b64decode(cypher_part[::-1] + '==').decode('utf-8', errors='ignore')
                except Exception:
                    url_map = cypher
                    
                # Extraction des coordonnées géographiques
                if url_map and "daddr=" in url_map:
                    try:
                        coords = url_map.split("daddr=")[1].split(",")
                        if len(coords) >= 2:
                            latitude = float(coords[0])
                            longitude = float(coords[1])
                    except Exception:
                        pass

            pharmacie = {
                "nom": nom,
                "statut_actuel": statut,
                "adresse": adresse,
                "telephone": telephone,
                "itineraire_google_maps": url_map,
                "latitude": latitude,
                "longitude": longitude,
                "horaires_ouverture": horaires
            }
            
            toutes_les_pharmacies.append(pharmacie)

        if nouveaux_elements_page == 0:
            print("Aucune nouvelle pharmacie trouvée sur cette page, on a atteint la limite de pagination.")
            break

        page_num += 1
        time.sleep(1) # Petite pause pour ne pas surcharger le serveur

    # Sauvegarder dans un fichier JSON
    fichier_sortie = 'pharmacies_goafrica.json'
    with open(fichier_sortie, 'w', encoding='utf-8') as f:
        json.dump(toutes_les_pharmacies, f, ensure_ascii=False, indent=4)
        
    print(f"\nScraping terminé ! {len(toutes_les_pharmacies)} pharmacies ont été sauvegardées dans '{fichier_sortie}'")

if __name__ == "__main__":
    scraper_goafricaonline()
