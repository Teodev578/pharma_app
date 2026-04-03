import json
import firebase_admin
from firebase_admin import credentials, firestore

# Initialisation de Firebase
# Remplacez 'serviceAccountKey.json' par le chemin vers votre fichier de clé téléchargé
cred = credentials.Certificate('serviceAccountKey.json')
firebase_admin.initialize_app(cred)

db = firestore.client()

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
    
    # Insertion dans Firestore
    collection_name = "pharmacies"
    inserted_count = 0
    error_count = 0
    
    for i, pharma in enumerate(pharmacies):
        try:
            # On utilise le nom de la pharmacie comme ID de document pour éviter les doublons 
            # (ou on laisse Firestore générer un ID auto avec .add())
            # Ici on laisse auto-générer pour plus de flexibilité
            db.collection(collection_name).add(pharma)
            inserted_count += 1
            if (i + 1) % 50 == 0 or (i + 1) == total_pharmacies:
                print(f"Progress : {i + 1} / {total_pharmacies}")
        except Exception as e:
            error_count += 1
            print(f"Erreur lors de l'insertion de {pharma.get('nom')} : {e}")
            
    print(f"Terminé : {inserted_count} pharmacies insérées avec succès, {error_count} erreurs.")

if __name__ == "__main__":
    main()
