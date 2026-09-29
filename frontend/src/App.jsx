import { useEffect, useRef, useState } from "react";



import birdVisionLogo from "./assets/birdvision-logo.png";



import Login from "./pages/Login";



import SplashScreen from "./pages/SplashScreen";



import "./App.css";





function App() {

  /* ======================================================

     SPLASH SCREEN

     ====================================================== */



  const [showSplash, setShowSplash] = useState(true);





  /* ======================================================

     AUTHENTIFICATION

     ====================================================== */



  const [isAuthenticated, setIsAuthenticated] = useState(false);



  const [currentUser, setCurrentUser] = useState(null);





  /* ======================================================

     DÉTECTION

     ====================================================== */



  const [image, setImage] = useState(null);



  const [preview, setPreview] = useState(null);



  const [result, setResult] = useState(null);



  const [loading, setLoading] = useState(false);



  const [error, setError] = useState("");

  const fileInputRef = useRef(null);




  /* ======================================================

     PARAMÈTRES IA

     ====================================================== */



  const [selectedModel, setSelectedModel] =

    useState("rtdetr-x");



  const [confidenceThreshold, setConfidenceThreshold] = useState(0.25);





  /* ======================================================

     NOM DU MODÈLE

     ====================================================== */



  const selectedModelName =

    selectedModel === "rtdetr-x"

      ? "RT-DETR-X"

      : selectedModel === "yolo26s"

        ? "YOLO26s"

        : selectedModel === "dfine-x"

          ? "D-FINE-X"

          : "Modèle inconnu";





  /* ======================================================

     SPLASH SCREEN — 5 SECONDES

     ====================================================== */



  useEffect(() => {

    const timer = setTimeout(() => {

      setShowSplash(false);

    }, 5000);



    return () => {

      clearTimeout(timer);

    };

  }, []);





  /* ======================================================

     NETTOYAGE DE L'APERÇU

     ====================================================== */



  useEffect(() => {

    return () => {

      if (preview) {

        URL.revokeObjectURL(preview);

      }

    };

  }, [preview]);





  /* ======================================================

     CONNEXION

     ====================================================== */



  const handleLogin = (userData) => {

    setCurrentUser(userData);



    setIsAuthenticated(true);

  };





  /* ======================================================

     DÉCONNEXION

     ====================================================== */



  const handleLogout = () => {

    handleReset();



    setCurrentUser(null);



    setIsAuthenticated(false);

  };





  /* ======================================================

     CHANGEMENT DU MODÈLE

     ====================================================== */



  const handleModelChange = (event) => {

    setSelectedModel(event.target.value);



    // On efface l'ancien résultat afin de ne pas afficher

    // un résultat provenant d'un autre modèle.



    setResult(null);



    setError("");

  };





  /* ======================================================

     SÉLECTION IMAGE

     ====================================================== */



  const handleImageChange = (event) => {

    const file = event.target.files?.[0];



    if (!file) return;



    const allowedTypes = [

      "image/jpeg",

      "image/png",

    ];



    if (!allowedTypes.includes(file.type)) {

      setError(

        "Veuillez sélectionner une image JPG, JPEG ou PNG."

      );



      return;

    }



    if (preview) {

      URL.revokeObjectURL(preview);

    }



    setImage(file);



    setPreview(URL.createObjectURL(file));



    setResult(null);



    setError("");

  };





  /* ======================================================

     DÉTECTION

     RT-DETR-X / YOLO26s / D-FINE-X

     ====================================================== */



  const handleDetect = async () => {

    if (!image) {

      setError(

        "Veuillez sélectionner une image."

      );



      return;

    }



    setLoading(true);



    setError("");



    setResult(null);



    const formData = new FormData();



    /*

     * Données envoyées au backend Django :

     *

     * image       = fichier image

     * confidence  = 0.70

     * model       = rtdetr-x, yolo26s ou dfine-x

     */



    formData.append("image", image);



    formData.append(

      "confidence",

      confidenceThreshold.toFixed(2)

    );



    formData.append(

      "model",

      selectedModel

    );



    try {

      const response = await fetch(

        "http://127.0.0.1:8000/api/detect/",

        {

          method: "POST",

          body: formData,

        }

      );



      let data;



      try {

        data = await response.json();

      } catch {

        throw new Error(

          "Le serveur a retourné une réponse invalide."

        );

      }



      if (!response.ok) {

        throw new Error(

          data.error ||

            "Une erreur est survenue pendant la détection."

        );

      }



      setResult(data);

    } catch (err) {

      console.error(

        "Erreur BirdVision :",

        err

      );



      if (err instanceof TypeError) {

        setError(

          "Impossible de communiquer avec le serveur BirdVision. Vérifiez que Django est démarré."

        );

      } else {

        setError(

          err.message ||

            "Une erreur est survenue pendant l'analyse."

        );

      }

    } finally {

      setLoading(false);

    }

  };





  /* ======================================================

     NOUVELLE ANALYSE

     ====================================================== */



  const handleReset = () => {

    if (preview) {

      URL.revokeObjectURL(preview);

    }



    setImage(null);



    setPreview(null);



    setResult(null);



    setError("");



    setLoading(false);

  };





  /* ======================================================

     CONFIANCE MOYENNE

     ====================================================== */



  const averageConfidence =

    result?.detections?.length > 0

      ? (

          (result.detections.reduce(

            (sum, detection) =>

              sum + detection.confidence,

            0

          ) /

            result.detections.length) *

          100

        ).toFixed(1)

      : null;





  /* ======================================================

     SPLASH SCREEN

     ====================================================== */



  if (showSplash) {

    return <SplashScreen />;

  }





  /* ======================================================

     PAGE LOGIN

     ====================================================== */



  if (!isAuthenticated) {

    return (

      <Login

        onLogin={handleLogin}

      />

    );

  }





  /* ======================================================

     APPLICATION BIRDVISION

     ====================================================== */



  return (

    <div className="app">



      {/* ==================================================

          NAVIGATION

          ================================================== */}



      <header className="topbar">



        <div className="nav-container">



          {/* LOGO */}



          <a

            href="#analyse"

            className="brand"

          >



            <div className="brand-logo">



              <img

                src={birdVisionLogo}

                alt="Logo BirdVision IA"

              />



            </div>



            <div className="brand-text">



              <h1>

                BirdVision{" "}

                <span className="brand-ia">

                  IA

                </span>

              </h1>



              <span>

                Intelligence Artificielle

              </span>



            </div>



          </a>





          {/* NAVIGATION */}



          <nav className="nav-links">



            <a

              href="#analyse"

              className="active"

            >

              Analyse

            </a>



            <a href="#technology">

              Technologie

            </a>

          </nav>


          {/* PARTIE DROITE */}

          <div className="nav-right">
            <div className="system-status">
              <span className="status-dot"></span>
              <div>
                <strong>
                  {selectedModelName}
                </strong>
                <small>
                  Modèle sélectionné
                </small>
              </div>
            </div>
            <button
              type="button"

              className="logout-button"

              onClick={handleLogout}

              title="Se déconnecter"

            >



              <span className="logout-icon">

                ↗

              </span>



              <span className="logout-text">

                Déconnexion

              </span>



            </button>



          </div>



        </div>



      </header>





      <main>



        {/* ==================================================

            HERO

            ================================================== */}



        <section className="hero">



          <div className="hero-glow hero-glow-one"></div>



          <div className="hero-glow hero-glow-two"></div>



          <div className="hero-inner">



            <div className="eyebrow">



              <span className="eyebrow-dot"></span>



              COMPUTER VISION • BIRD DETECTION



            </div>





            <h2>

              Détectez les oiseaux avec

              <span>

                {" "}

                l'intelligence artificielle.

              </span>

            </h2>





            <p>

              BirdVision IA utilise des modèles de

              vision par ordinateur pour détecter

              et localiser automatiquement les

              oiseaux présents dans vos images.

            </p>





            <div className="hero-features">



              {/* FEATURE 1 */}



              <div className="hero-feature">



                <span className="feature-icon">

                  AI

                </span>



                <div>



                  <strong>

                    {selectedModelName}

                  </strong>



                  <small>

                    Modèle sélectionné

                  </small>



                </div>



              </div>





              {/* FEATURE 2 */}



              <div className="hero-feature">



                <span className="feature-icon">

                  {Math.round(confidenceThreshold * 100)}

                </span>



                <div>



                  <strong>

                    {Math.round(confidenceThreshold * 100)} %

                  </strong>



                  <small>

                    Seuil de confiance

                  </small>



                </div>



              </div>





              {/* FEATURE 3 */}



              <div className="hero-feature">



                <span className="feature-icon">

                  CV

                </span>



                <div>



                  <strong>

                    Computer Vision

                  </strong>



                  <small>

                    Analyse intelligente

                  </small>



                </div>



              </div>



            </div>



          </div>



        </section>





        {/* ==================================================

            ESPACE ANALYSE

            ================================================== */}



        <section

          className="analysis-section"

          id="analyse"

        >



          {/* TITRE */}



          <div className="section-heading">



            <div>



              <span className="section-kicker">

                ESPACE D'ANALYSE

              </span>



              <h2>

                Analysez une image

              </h2>



              <p>

                Importez une photographie,

                choisissez votre modèle IA et

                laissez BirdVision IA rechercher

                automatiquement les oiseaux.

              </p>



            </div>





            <div className="analysis-badge">



              <span></span>



              Système prêt



            </div>



          </div>





          {/* ==================================================

              WORKSPACE

              ================================================== */}



          <div className="workspace">





            {/* ==================================================

                IMAGE SOURCE

                ================================================== */}



            <article className="panel upload-panel">



              <div className="panel-header">



                <div className="panel-title">



                  <span className="step-number">

                    01

                  </span>



                  <div>



                    <span className="panel-label">

                      IMAGE SOURCE

                    </span>



                    <h3>

                      Importer une image

                    </h3>



                  </div>



                </div>





                <span className="file-type-badge">

                  JPG / PNG

                </span>



              </div>





              {/* DROP ZONE */}



              <label

                className={`drop-zone ${

                  preview

                    ? "has-image"

                    : ""

                }`}

              >



                {preview ? (

                  <>



                    <img

                      src={preview}

                      alt="Aperçu sélectionné"

                      className="preview-image"

                    />



                    <div className="image-overlay">



                      <span>

                        Cliquer pour remplacer

                        l'image

                      </span>



                    </div>



                  </>

                ) : (



                  <div className="upload-placeholder">



                    <div className="upload-icon">



                      <span>

                        ↑

                      </span>



                    </div>



                    <h4>

                      Déposez votre image ici

                    </h4>



                    <p>

                      Cliquez pour parcourir vos

                      fichiers et sélectionner une

                      image à analyser.

                    </p>



                    <span className="formats">

                      JPG, JPEG ou PNG

                    </span>



                  </div>

                )}





                <input

                  ref={fileInputRef}

                  type="file"

                  accept="image/png,image/jpeg"

                  onChange={handleImageChange}

                  disabled={loading}

                  hidden

                />



              </label>





              {/* FICHIER SÉLECTIONNÉ */}



              {image && (



                <div className="selected-file">



                  <div className="file-icon">

                    IMG

                  </div>



                  <div className="file-details">



                    <strong>

                      {image.name}

                    </strong>



                    <span>

                      {(

                        image.size /

                        1024 /

                        1024

                      ).toFixed(2)}

                      {" MB • "}

                      Image prête

                    </span>



                  </div>





                  {!loading && (



                    <label className="change-file">



                      Modifier



                      <input

                        ref={fileInputRef}

                        type="file"

                        accept="image/png,image/jpeg"

                        onChange={

                          handleImageChange

                        }

                        hidden

                      />



                    </label>

                  )}



                </div>

              )}





              {/* ==================================================

                  PARAMÈTRES D'ANALYSE

                  ================================================== */}



              <div className="model-settings">



                <div className="model-settings-header">



                  <div>



                    <span className="panel-label">

                      PARAMÈTRES D'ANALYSE

                    </span>



                    <h4>

                      Modèle de détection

                    </h4>



                  </div>



                  <span className="model-status">

                    AI

                  </span>



                </div>





                <div className="model-select-wrapper">



                  <label htmlFor="model-select">

                    Choisir le modèle

                  </label>





                  <select

                    id="model-select"

                    value={selectedModel}

                    onChange={handleModelChange}

                    disabled={loading}

                  >



                    <option value="rtdetr-x">

                      RT-DETR-X

                    </option>



                    <option value="yolo26s">

                      YOLO26s

                    </option>



                    <option value="dfine-x">

                      D-FINE-X

                    </option>



                  </select>



                </div>





                {/* SEUIL DE CONFIANCE */}

                <div className="confidence-setting">
                  <div className="confidence-setting-header">
                    <label htmlFor="confidence-range">Seuil de confiance</label>
                    <strong>{Math.round(confidenceThreshold * 100)} %</strong>
                  </div>

                  <input
                    id="confidence-range"
                    type="range"
                    min="0.10"
                    max="0.90"
                    step="0.05"
                    value={confidenceThreshold}
                    onChange={(event) => {
                      setConfidenceThreshold(Number(event.target.value));
                      setResult(null);
                      setError("");
                    }}
                    disabled={loading}
                  />

                  <div className="confidence-scale">
                    <span>10 %</span>
                    <span>50 %</span>
                    <span>90 %</span>
                  </div>

                  <p className="confidence-help">
                    Un seuil plus faible détecte davantage d'oiseaux, mais peut produire plus de fausses détections.
                  </p>
                </div>

                <div className="selected-model-info">



                  <div className="selected-model-icon">

                    AI

                  </div>



                  <div>



                    <span>

                      Modèle sélectionné

                    </span>



                    <strong>

                      {selectedModelName}

                    </strong>



                  </div>



                </div>



              </div>





              {/* BOUTON ANALYSER */}



              <button

                className="primary-button"

                onClick={handleDetect}

                disabled={

                  !image ||

                  loading

                }

              >



                {loading ? (

                  <>



                    <span className="button-loader"></span>



                    Analyse avec{" "}

                    {selectedModelName}...



                  </>

                ) : (

                  <>



                    <span className="button-spark">

                      ✦

                    </span>



                    Analyser avec{" "}

                    {selectedModelName}



                    <span className="button-arrow">

                      →

                    </span>



                  </>

                )}



              </button>





              {/* NOUVELLE ANALYSE */}



              {(result || error) &&

                !loading && (



                  <button

                    className="secondary-button"

                    onClick={handleReset}

                  >

                    Nouvelle analyse

                  </button>

                )}



            </article>





            {/* ==================================================

                RÉSULTAT

                ================================================== */}



            <article className="panel result-panel">



              <div className="panel-header">



                <div className="panel-title">



                  <span className="step-number">

                    02

                  </span>



                  <div>



                    <span className="panel-label">

                      RÉSULTAT IA

                    </span>



                    <h3>

                      Résultat de l'analyse

                    </h3>



                  </div>



                </div>





                {result ? (



                  <span className="complete-badge">



                    <span>

                      ✓

                    </span>



                    Terminée



                  </span>



                ) : (



                  <span className="waiting-badge">

                    En attente

                  </span>



                )}



              </div>





              <div className="result-view">





                {/* ============================================

                    CHARGEMENT

                    ============================================ */}



                {loading && (



                  <div className="loading-state">



                    <div className="scanner">



                      <div className="scanner-circle">



                        <span>

                          AI

                        </span>



                      </div>



                      <div className="scanner-ring"></div>



                    </div>





                    <h4>

                      Analyse intelligente en cours

                    </h4>



                    <p>

                      {selectedModelName} inspecte

                      votre image pour localiser les

                      oiseaux.

                    </p>



                    <div className="progress-track">



                      <div className="progress-bar"></div>



                    </div>



                    <span className="loading-caption">

                      Traitement par Computer Vision

                    </span>



                  </div>

                )}





                {/* ============================================

                    ERREUR

                    ============================================ */}



                {!loading &&

                  error && (



                    <div className="error-state">



                      <div className="state-icon error-state-icon">

                        !

                      </div>



                      <h4>

                        Analyse impossible

                      </h4>



                      <p>

                        {error}

                      </p>



                    </div>

                  )}





                {/* ============================================

                    EN ATTENTE

                    ============================================ */}



                {!loading &&

                  !error &&

                  !result && (



                    <div className="empty-state">



                      <div className="empty-visual">



                        <div className="focus-corner corner-one"></div>



                        <div className="focus-corner corner-two"></div>



                        <div className="focus-corner corner-three"></div>



                        <div className="focus-corner corner-four"></div>



                        <span>

                          AI

                        </span>



                      </div>



                      <h4>

                        Prêt pour l'analyse

                      </h4>



                      <p>

                        Sélectionnez une image et

                        choisissez un modèle IA.

                        Le résultat annoté

                        apparaîtra ici après

                        l'analyse.

                      </p>



                    </div>

                  )}





                {/* ============================================

                    RÉSULTAT

                    ============================================ */}



                {!loading &&

                  !error &&

                  result && (

                    <>



                      {result.result_image && (



                        <div className="result-image-wrapper">



                          <img

                            src={

                              result.result_image

                            }

                            alt={`Résultat de la détection ${selectedModelName}`}

                            className="result-image"

                          />



                          <div className="result-image-label">



                            <span></span>



                            Détection{" "}

                            {selectedModelName}



                          </div>



                        </div>

                      )}





                      {result.bird_count > 0 ? (



                        <div className="result-message success-result">



                          <div className="result-message-icon">

                            ✓

                          </div>



                          <div>



                            <strong>

                              Analyse terminée

                              avec succès

                            </strong>



                            <span>



                              {

                                result.bird_count

                              }{" "}



                              {result.bird_count ===

                              1

                                ? "oiseau a été détecté"

                                : "oiseaux ont été détectés"}



                              {" avec "}



                              {selectedModelName}.



                            </span>



                          </div>



                        </div>



                      ) : (



                        <div className="result-message neutral-result">



                          <div className="result-message-icon">

                            ○

                          </div>



                          <div>



                            <strong>

                              Aucun oiseau détecté

                            </strong>



                            <span>

                              Aucun oiseau n'a

                              atteint le seuil

                              minimum de confiance

                              de {Math.round(confidenceThreshold * 100)} % avec{" "}

                              {selectedModelName}.

                            </span>



                          </div>



                        </div>

                      )}



                    </>

                  )}



              </div>



            </article>



          </div>





          {/* ==================================================

              STATISTIQUES

              ================================================== */}



          <div className="stats-grid">



            {/* OISEAUX */}



            <div className="stat-card">



              <div className="stat-icon">

                01

              </div>



              <div>



                <span>

                  Oiseaux détectés

                </span>



                <strong>

                  {result

                    ? result.bird_count

                    : "—"}

                </strong>



              </div>



            </div>





            {/* CONFIANCE */}



            <div className="stat-card">



              <div className="stat-icon">

                %

              </div>



              <div>



                <span>

                  Confiance moyenne

                </span>



                <strong>

                  {averageConfidence

                    ? `${averageConfidence} %`

                    : "—"}

                </strong>



              </div>



            </div>





            {/* MODÈLE */}



            <div className="stat-card">



              <div className="stat-icon">

                AI

              </div>



              <div>



                <span>

                  Modèle IA

                </span>



                <strong>

                  {selectedModelName}

                </strong>



              </div>



            </div>





            {/* SEUIL */}



            <div className="stat-card">



              <div className="stat-icon">

                {Math.round(confidenceThreshold * 100)}

              </div>



              <div>



                <span>

                  Seuil minimum

                </span>



                <strong>

                  {Math.round(confidenceThreshold * 100)} %

                </strong>



              </div>



            </div>



          </div>





          {/* ==================================================

              DÉTAILS DES DÉTECTIONS

              ================================================== */}



          {result?.detections?.length >

            0 && (



            <section className="detection-details">



              <div className="details-heading">



                <div>



                  <span className="section-kicker">

                    DONNÉES DE DÉTECTION

                  </span>



                  <h3>

                    Détails des oiseaux détectés

                  </h3>



                </div>





                <span className="detection-count">



                  {

                    result.detections

                      .length

                  }{" "}



                  détection(s)



                </span>



              </div>





              <div className="detections-grid">



                {result.detections.map(

                  (

                    detection,

                    index

                  ) => (



                    <div

                      className="detection-card"

                      key={index}

                    >



                      <div className="detection-index">



                        {String(

                          index + 1

                        ).padStart(

                          2,

                          "0"

                        )}



                      </div>





                      <div className="detection-info">



                        <strong>

                          Oiseau{" "}

                          {index + 1}

                        </strong>



                        <span>

                          Objet détecté

                        </span>



                      </div>





                      <div className="confidence-value">



                        <span>

                          Confiance

                        </span>



                        <strong>



                          {(

                            detection.confidence *

                            100

                          ).toFixed(1)}



                          {" %"}



                        </strong>



                      </div>



                    </div>

                  )

                )}



              </div>



            </section>

          )}



        </section>





        {/* ==================================================

            TECHNOLOGIE

            ================================================== */}



        <section

          className="technology-section"

          id="technology"

        >



          <div>



            <span className="section-kicker">

              TECHNOLOGIE

            </span>



            <h2>

              Une architecture conçue pour la

              vision par ordinateur.

            </h2>



          </div>





          <div className="tech-stack">



            <span>

              RT-DETR-X

            </span>



            <span>

              YOLO26s

            </span>



            <span>

              D-FINE-X

            </span>



            <span>

              Django REST

            </span>



            <span>

              React

            </span>



            <span>

              Computer Vision

            </span>



          </div>



        </section>



      </main>





      {/* ==================================================

          FOOTER

          ================================================== */}



      <footer className="footer">



        <div className="footer-inner">



          <div className="footer-brand">



            <div className="footer-logo">



              <img

                src={birdVisionLogo}

                alt="BirdVision IA"

              />



            </div>





            <div>



              <strong>

                BirdVision IA

              </strong>



              <span>

                Détection intelligente

                d'oiseaux

              </span>



            </div>



          </div>





          <p>

            Computer Vision • RT-DETR-X •

            YOLO26s • D-FINE-X • Django REST • React

          </p>



        </div>



      </footer>



    </div>

  );

}





export default App;