[OK] 1. Create a sqflite cache provider and implement it
[OK] 2. Implement the search but change it to only search Animes. Use the searchAnime on jikan_service.dart
[OK] 3. Add a genres slider as the last item of the home page. When clicked, open the AnimeListScreen with the first page of the results. Make that screen accept pageLoad which will be a function to fetch the page(number) and make the scroll infinite until all the animes from the selected genre have been shown.
[OK] 4. Create a addFavorite and removeFavorite on the user_anime_service, this will be stored under users/(userid)/favorites, storing the full anime object.
[OK] 5. Add debugging to SQLITE cache provider
[OK] 6. Settings page
[OK] 7. Notification Settings Page
[  ] 8. Remove Account page
[OK] 9. Cache network images
[  ] 10. Implement https://pub.dev/packages/in_app_review when the user follow it's second anime the review should show for the first time.
[  ] 11. Implement https://pub.dev/packages/flutter_native_splash
[OK] 12. When the user confirms that he'll be  adding the anime to his watchlist in the dialog, use the user_anime_service and the follow method to add it.
[OK] 13. Store the user followedAnimes in an easier way to read, and store it to app state to make it easier to access.
[  ] 14. Implement the share button
[OK] 15. Add the real AdMob ids for both platforms
[NO] 16. Make a background service to setup local notifications
[OK] 17. Add a Theme Switcher between light and dark, and persist those between app restarts by using localstorage package, it should work on the settings page but be on the topbar in the home page as well
[  ] 18. Implement https://pub.dev/packages/in_app_purchase with the subscriptions (Stores Required)
[OK] 19. Use Youtube Data Api to find trailers for the animes when opening details. If found, save then to Firestore animes/(animeid)/videos and fetch from there next time it's opened. After fetching the videos, also cache then, and try to hit cache before firestore, before fetching from youtube data api. The api key is in remote config YOUTUBE_DATA_API_KEY
[OK] 20. Create privacy policy and terms of use
[OK] 21. When opening the app, get the release schedule for the next week, cache it with 1 day of duration, this will be fetched later on the app
[OK] 22. Create a calendar screen with this week releases, show every release but highlight the if there're followed animes releasing, add a toggle at the top to (show only followed) and add a button at the bottom to "sync my calendar"with a placeholder action that we'll implement later, add the icon to access the calendar at the topbar action, at the left, a calendar icon
[OK] 23. Change the Youtube Data Api Video Prompt to 'Anime Trailer Official Eng Sub {Anime Name}'