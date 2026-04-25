================================================================================
  TEXORA - AI Fashion Design App
  User Workflow
================================================================================

ABOUT THE APP
--------------
Texora is an AI-powered fashion design app that helps users scan fabric,
analyse colors and textures, generate unique fashion design concepts using
artificial intelligence, and build a personal fabric collection — all from
their mobile device.


--------------------------------------------------------------------------------
  USER WORKFLOW
--------------------------------------------------------------------------------

1. LAUNCHING THE APP
----------------------

  - Click Terminal and select a new terminal inside the project
  - In that Terminal type - flutter pub get then after it completes then type flutter run to open the app 
  
  The user opens the app and is greeted with a short loading screen while
  the app gets ready. If the user has already logged in before, they are
  taken directly to the main screen. If not, they are guided through the
  onboarding experience.


2. ONBOARDING SLIDES
----------------------
  First-time users see a beautiful 3-page onboarding screen showcasing what
  the app offers:

    Page 1 — "Elevate Your Design"
      Learn how Texora helps you discover your unique fashion identity.

    Page 2 — "AI-Driven Analysis"
      Discover how cutting-edge AI analyses fabric texture and color.

    Page 3 — "Precision Style Hub"
      Build and manage your personal fashion collection with ease.

  The user can swipe through the pages or tap the button at the bottom
  to move forward. On the last page, tapping "Get Started" takes the user
  to the login screen.


3. WELCOME / AUTH SCREEN
--------------------------
  The user lands on a full-screen welcome page with two options:

    → Create Account   — for new users
    → Log In           — for returning users

  There is also a "Sign Up" shortcut link at the bottom of the screen.


4. CREATING AN ACCOUNT (REGISTER)
------------------------------------
  New users tap "Create Account" and fill in the registration form:

    - Email address
    - Password
    - Confirm Password
    - Agree to Terms & Privacy (checkbox)

  After tapping "Sign Up", the account is created and a success message
  appears. The user is then automatically switched to the Login form to
  sign in with their new credentials.

  Alternatively, the user can sign up instantly using their Google account
  by tapping "Continue with Google".


5. LOGGING IN
---------------
  Returning users fill in the login form:

    - Email address
    - Password
    - Optional: "Remember Me" checkbox to stay signed in
    - "Forgot Password?" link if the password is lost

  After tapping "Log In", the user is taken into the main app.

  Google Sign-In is also available for a one-tap login experience.

  NOTE: The Login and Register forms are on the same screen. The user can
  switch between them at any time using the "Log In / Sign Up" tab at the
  top of the form — no need to go back.


6. HOME SCREEN
----------------
  After logging in, the user lands on the Home Screen. The app has three
  main sections accessible from the bottom navigation bar:

    [ Scan ]   [ Collection ]   [ Profile ]

  First-time users are shown a quick tutorial overlay that guides them
  through the main features of the app.


7. SCANNING FABRIC (CORE FEATURE)
------------------------------------
  The user taps the Scan tab to analyse a piece of fabric.

  Step 1 — Upload the Fabric
    The user picks a photo of the fabric from their camera or gallery.
    They can crop the image to focus on the fabric area.

  Step 2 — Choose Design Preferences
    Before generating, the user selects:
      - Style       (e.g. Casual, Formal, Streetwear, Evening Wear, Traditional)
      - Gender      (e.g. Male, Female, Unisex)
      - Garment     (e.g. Shirt, Dress, Jacket, etc.)
      - Custom Prompt (optional — describe specific design ideas)

  Step 3 — AI Analysis
    The app automatically:
      - Identifies the fabric type (e.g. cotton, silk, denim)
      - Extracts the dominant colors from the fabric
      - Generates a fashion design concept tailored to the fabric

  Step 4 — View the Design Sketch
    Using the analysis results, the app generates a visual AI fashion sketch
    showing how a garment made from this fabric could look.

  Step 5 — Save the Design
    The user can save the sketch and design concept to their personal
    collection for future reference.


8. AI DESIGN PAGE
-------------------
  After a design is generated, the user is taken to the AI Design screen
  where they can:

    - View the generated fashion sketch in full detail
    - Regenerate the design to explore different variations
    - Save the final design to their collection

  Generating designs uses credits. The user's current credit balance is
  shown on screen. Additional credits can be purchased from within the app.


9. MY COLLECTION (FABRIC LIBRARY)
------------------------------------
  The user taps the Collection tab to browse everything they have saved.

  The collection is split into two tabs:

    Scans    — all fabric scans with their analysis results and dominant colors
    Designs  — all AI-generated fashion sketches

  The user can tap any item to view the full details, and can delete items
  they no longer need.


10. PROFILE
-------------
  The user taps the Profile tab to manage their account.

  From here the user can:
    - View their name, email, and profile photo
    - Check their current AI credit balance
    - Edit their profile (update name or profile photo)
    - Sign out of the app

  After signing out, the user is returned to the Welcome / Auth screen.