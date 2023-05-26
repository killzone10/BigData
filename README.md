
# TBD (phase1b)

## Przeanalizuj log z workflow i odpowiedz: Co wykonywane jest w pierwszym kroku - “Set up job”?

GitHub oferuje hostowane maszyny wirtualne 'GitHub-hosted runners' do wykonywania workflowów. W set-up job konfigurujemy środowisko GitHub runnera (system operacyjny Ubuntu wraz z linkiem do odpowiedniego obrazu). Dodajemy odpowiednie _permissions_ dla wybranych tokenów GH, wybieramy źródło _GitHub secretów_. Pobierane są używane w dalszej kolejności repozytoria _GitHub actions_, m.in. _hashicorp/setup-terraform, google-github-actions/setup-gcloud, terraform-linters/setup-tflint, infracost/actions, bridgecrewio/checkov-action, actions/checkout, actions/github-script._

## Przeanalizuj błędy jakie pojawią się podczas wykonania Terraform plan i dodaj odpowiednie zmienne. Odpowiedz: Które zmienne trzeba było dodać?
Nie można było wykonać terraformp planu ponieważ nie zadeklarowano zmiennych.

Dodano poniższe zmienne do github secrets:

<img width="645" alt="image" src="https://user-images.githubusercontent.com/58270970/204844509-a2fa3c65-102c-4590-942d-5757599068cf.png">

## W głównym katalogu repozytorium utwórz plik .tflint.hcl. Przeanalizuj i popraw błędy (w tym warning’i). Napisz co trzeba było wykonać.

![image](https://user-images.githubusercontent.com/73608866/204843419-4ce74ffd-a247-43d4-84f3-ed019a872255.png)

Zgłaszane były warningi dotyczące nieużywanych zmiennych (jak na obrazku). Zmienne te zostały usunięte z plików - zarówno deklaracje jak i przypisanie wartości. Error był spowodowany warningami - po naprawieniu znikł.

## Uruchom ponownie GA workflow i podaj wyliczony koszt (powinien być widoczny jako komentarz do PR). Podaj co jest najdroższym a co najtańszym składnikiem infry.



<img width="1056" alt="image" src="https://user-images.githubusercontent.com/58270970/204844930-1b52093d-308b-441c-8407-d15d7dc57da3.png">

<img width="883" alt="image" src="https://user-images.githubusercontent.com/58270970/204845207-664addd3-0456-43a1-96ab-51ea526af2fb.png">

<img width="883" alt="image" src="https://user-images.githubusercontent.com/58270970/204845311-3639bcb2-ec3c-489f-b445-6e7e1527c722.png">

Wyliczony koszt to 106$. Najdroższy moduł to module.gke.google_containter_cluster.primary, zawierający najdroższy składnik - cluster managment fee. Najtańszy to  module.gke.google_containter_node_pool.primary_preemtible_nodes, a jego najtańszy składnik - standard provisioned storage. 

Podane są również stawki za użytkowanie infrastruktury (np. opłata za wykonanie 10k operacji typu A), bez wyliczenia kosztów (nie znamy liczby i rodzaju operacji). 

## Opisz jak się zmieniły koszty pod dodatniu .infracost-usage.yml i z czego te zmiany wynikają. 



<img width="644" alt="image" src="https://user-images.githubusercontent.com/58270970/204846899-de25ff9b-65c9-4524-9fc3-b9f55f554cf4.png">

Koszty zmieniły się zgodnie z opisem planowanych akcji na infrastrukturze zawartym w  _.infracost-usage.yml_ (wielkości takie jak: storage_gb,              monthly_class_a_operations, monthly_class_b_operations, monthly_data_retrieval_gb). Nowe koszty wyliczone na podstawie planowanego użycia za poszczególne składniki widoczne sa poniżej: 

<img width="531" alt="image" src="https://user-images.githubusercontent.com/58270970/204848117-a0bd7386-76f6-45bd-a866-5d23bed60dca.png">

## W podobny sposób spróbuj podać szacunki dla pozostałych zmiennych i pokaż wyniki.

Oszacowalismy przykładowe zużycie dla niewykorzystanych zmiennych. Pozostałe wykorzystywane w infrastrukturze resources są (według dokumentacji https://www.infracost.io/docs/supported_resources/google/) darmowe lub nieobsługiwane. 

Oszacowano następujące zużycie innych zmiennych:

<img width="305" alt="image" src="https://user-images.githubusercontent.com/58270970/204861480-ced37d9f-6f4b-49df-811f-3dfad83bdea3.png">


Szacunkowe koszty takiego wykorzystania infrastruktury to:

<img width="633" alt="image" src="https://user-images.githubusercontent.com/58270970/204861172-b2441371-a8f1-4b6f-b1f9-c6fc6bf6ab83.png">

Nowe wykorzystane zmienne:

<img width="639" alt="image" src="https://user-images.githubusercontent.com/58270970/204861290-47956646-3ceb-4d31-9d88-0ee5bfd2ba84.png">





