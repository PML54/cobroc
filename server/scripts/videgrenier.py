import requests
from bs4 import BeautifulSoup
from datetime import datetime
import pandas as pd

# URL de la page
url = "https://vide-greniers.org/evenements/Pontoise-95?distance=50"

# Récupérer le contenu
response = requests.get(url)

if response.status_code == 200:
    soup = BeautifulSoup(response.content, 'html.parser')
    events = []

    # Sélecteurs adaptés (à vérifier)
    event_divs = soup.find_all('div', class_='event')  # Balise conteneur

    for event in event_divs:
        # Titre
        title_tag = event.find('h2', class_='event-title')
        title = title_tag.text.strip() if title_tag else "Non spécifié"

        # Date
        date_tag = event.find('span', class_='event-date')
        date_str = date_tag.text.strip() if date_tag else "Non spécifiée"

        # Lieu
        location_tag = event.find('span', class_='event-location')
        location = location_tag.text.strip() if location_tag else "Non spécifié"

        # Conversion de la date (ex: "15 juin 2026" → datetime)
        try:
            # Si la date est au format "15 juin 2026"
            date = datetime.strptime(date_str, '%d %B %Y')
        except ValueError:
            try:
                # Si la date est au format "15/06/2026"
                date = datetime.strptime(date_str, '%d/%m/%Y')
            except ValueError:
                date = None

        events.append({
            'Titre': title,
            'Date': date,
            'Lieu': location,
            'Date_str': date_str
        })

    # Filtrer et trier
    valid_events = [e for e in events if e['Date'] is not None]

    if not valid_events:
        print("Aucun événement trouvé. Vérifiez les sélecteurs ou la structure HTML.")
        print("Voici un extrait du HTML pour vous aider :")
        print(soup.prettify()[:1000])  # Affiche les 1000 premiers caractères du HTML
    else:
        sorted_events = sorted(valid_events, key=lambda x: x['Date'])
        df = pd.DataFrame(sorted_events)
        print(df[['Titre', 'Date_str', 'Lieu']])

        # Exporter en CSV
        # df.to_csv('evenements_trie_par_date.csv', index=False)

else:
    print(f"Erreur : {response.status_code}")