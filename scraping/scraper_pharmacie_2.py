from bs4 import BeautifulSoup
import requests
import json

def extraire_horaires(bouton):
    # On cherche dans tous les attributs de l'élément car on ne connaît pas 
    # le nom exact de l'attribut (ça peut être data-controller ou une valeur de data-...)
    for attr_name, attr_value in bouton.attrs.items():
        if isinstance(attr_value, str) and 'popoverClass' in attr_value:
            try:
                # Le contenu de cet attribut est un JSON
                data = json.loads(attr_value)
                
                # Le code HTML du tableau se trouve dans la clé 'content'
                content_html = data.get('content', '')
                content_soup = BeautifulSoup(content_html, 'html.parser')
                
                # On parse le tableau HTML
                rows = content_soup.find_all('tr')
                horaires = []
                for row in rows:
                    cols = row.find_all('td')
                    if len(cols) >= 2:
                        jour = ' '.join(cols[0].text.split())
                        heure = ' '.join(cols[1].text.split())
                        horaires.append(f"{jour} : {heure}")
                return horaires
            except Exception as e:
                return [f"Erreur de parsing des horaires : {e}"]
    return ["Données d'horaires non trouvées dans les attributs"]

def test_scraper():
    url = "https://www.goafricaonline.com/tg/annuaire/pharmacies"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
    }
    
    print(f"Fetching {url}... extraction des horaires en cours.")
    response = requests.get(url, headers=headers)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    # On identifie les blocs correspondant à chaque pharmacie
    elements = soup.find_all(lambda tag: tag.has_attr('class') and 'flex' in tag.get('class') and 'w-full' in tag.get('class'))
    
    for i, el in enumerate(elements[:3]): # Test rapide sur 3 pharmacies
        print(f"\n--- Pharmacie {i+1} ---")
        
        # Récupération du texte brut complet (comme dans la première version)
        text_brut = ' '.join(el.text.split())
        # On affiche tout le texte ou juste le début (ici je mets tout pour vous montrer qu'on a bien tout récupéré)
        print(f"Texte brut : {text_brut}\n")
        
        # Essai de récupération du nom
        nom_tag = el.find('a', class_=lambda c: c and 'text-' in c)
        if not nom_tag:
             nom_tag = el.find(['h2','h3','h4'])
        nom = nom_tag.text.strip() if nom_tag else "Nom inconnu"
        print(f"Nom : {nom}")
        
        # Trouver l'élément ("bouton") contenant les classes pour le popover.
        # Il peut être vert (bg-green-100) s'il est ouvert, ou un autre style s'il est fermé (ex: bg-red-100)
        btn_horaires = el.find(lambda tag: tag.has_attr('class') and ('bg-green-100' in tag.get('class') or 'bg-red-100' in tag.get('class') or 'bg-gray-100' in tag.get('class')))
        
        if btn_horaires:
            statut = btn_horaires.text.strip().split()[0] # Ex: "Ouvert" ou "Fermé"
            print(f"Statut actuel : {statut}")
            
            horaires = extraire_horaires(btn_horaires)
            print("Horaires d'ouverture :")
            for h in horaires:
                print(f"  {h}")
        else:
            print("Bouton horaires non trouvé pour cette pharmacie.")
            
if __name__ == "__main__":
    test_scraper()
