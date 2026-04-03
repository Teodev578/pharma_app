import json
import csv
import os

def format_horaires(horaires):
    """Formate la liste des horaires en une chaîne de caractères lisible."""
    if not horaires:
        return "Non spécifié"
    
    formatted = []
    for h in horaires:
        formatted.append(f"{h['jour']}: {h['heure']}")
    return " | ".join(formatted)

def main():
    json_file = "pharmacies_goafrica.json"
    csv_file = "pharmacies_export.csv"
    
    # Lecture du fichier JSON
    if not os.path.exists(json_file):
        print(f"Erreur : Le fichier {json_file} est introuvable.")
        return
        
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            pharmacies = json.load(f)
    except Exception as e:
        print(f"Erreur lors de la lecture du JSON : {e}")
        return
        
    print(f"Exportation de {len(pharmacies)} pharmacies...")
    
    # Définition des colonnes du CSV
    fieldnames = [
        "Nom", 
        "Statut", 
        "Adresse", 
        "Téléphone", 
        "Latitude", 
        "Longitude", 
        "Itinéraire Maps", 
        "Horaires"
    ]
    
    try:
        with open(csv_file, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for p in pharmacies:
                writer.writerow({
                    "Nom": p.get("nom", ""),
                    "Statut": p.get("statut_actuel", ""),
                    "Adresse": p.get("adresse", ""),
                    "Téléphone": p.get("telephone", ""),
                    "Latitude": p.get("latitude", ""),
                    "Longitude": p.get("longitude", ""),
                    "Itinéraire Maps": p.get("itineraire_google_maps", ""),
                    "Horaires": format_horaires(p.get("horaires_ouverture", []))
                })
        
        print(f"Exportation réussie ! Le document est disponible ici : {csv_file}")
        
    except Exception as e:
        print(f"Erreur lors de l'écriture du CSV : {e}")

if __name__ == "__main__":
    main()
