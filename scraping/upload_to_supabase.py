import json
import os
from dotenv import load_dotenv
from supabase import create_client, Client

# Charger les variables d'environnement depuis le fichier .env
load_dotenv()

# L'utilisateur doit définir ces variables dans un fichier .env à la racine
url: str = os.environ.get("SUPABASE_URL")
key: str = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Erreur : SUPABASE_URL et SUPABASE_KEY doivent être définis dans le fichier .env")
    exit(1)

# Création du client Supabase
supabase: Client = create_client(url, key)

def main():
    file_path = "pharmacies_goafrica.json"
    
    # Lecture du fichier JSON contenant les données
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            pharmacies = json.load(f)
    except FileNotFoundError:
        print(f"Erreur: Le fichier {file_path} est introuvable.")
        return
        
    total_pharmacies = len(pharmacies)
    print(f"{total_pharmacies} pharmacies trouvées dans le fichier JSON.")
    
    # Taille des lots pour l'insertion (évite les timeouts)
    batch_size = 50
    inserted_count = 0
    error_count = 0
    
    for i in range(0, total_pharmacies, batch_size):
        batch = pharmacies[i:i+batch_size]
        try:
            # Insertion du lot dans la base de données
            response = supabase.table("pharmacies").insert(batch).execute()
            inserted_count += len(response.data)
            print(f"Inséré : {inserted_count} / {total_pharmacies}")
        except Exception as e:
            error_count += len(batch)
            print(f"Erreur lors de l'insertion du lot {i} à {min(i+batch_size, total_pharmacies)} : {e}")
            
    print(f"Terminé : {inserted_count} pharmacies insérées avec succès, {error_count} erreurs.")

if __name__ == "__main__":
    main()
