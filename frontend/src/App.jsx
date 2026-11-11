import { useEffect, useRef, useState } from "react";

import birdVisionLogo from "./assets/birdvision-logo.png";

import Login from "./pages/Login";
import Register from "./pages/Register";
import Home from "./pages/Home";
import siribraLogo from "./assets/siribra-logo.png";

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



  // Vérifie si l'utilisateur est connecté
const [isAuthenticated, setIsAuthenticated] = useState(false);

// Permet de passer de Connexion à Inscription
const [authPage, setAuthPage] = useState("home");

// Informations de l'utilisateur connecté
const [currentUser, setCurrentUser] = useState(null);

// Token envoyé par Django après connexion
const [authToken, setAuthToken] = useState(null);





  /* ======================================================

     DÉTECTION

     ====================================================== */



  const [image, setImage] = useState(null);



  const [preview, setPreview] = useState(null);



  const [result, setResult] = useState(null);



  const [loading, setLoading] = useState(false);



  const [error, setError] = useState("");

  const fileInputRef = useRef(null);
  const videoFileInputRef = useRef(null);
  const videoTimerRef = useRef(null);



  /* ======================================================
     ONGLET ACTIF
     ====================================================== */

  const [activeTab, setActiveTab] = useState("image");

  /* ======================================================
     HISTORIQUE
     ====================================================== */
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(false);
  const [historyError, setHistoryError] = useState("");

  const fetchHistory = async () => {
    setHistoryLoading(true);
    setHistoryError("");
    try {
      const r = await fetch(`${import.meta.env.VITE_API_URL}/api/history/`, {
        headers: authToken ? { Authorization: `Token ${authToken}` } : {},
      });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || "Erreur serveur");
      setHistory(data.history || []);
    } catch (err) {
      setHistoryError(err.message || "Impossible de charger l'historique.");
    } finally {
      setHistoryLoading(false);
    }
  };

  useEffect(() => {
    if (isAuthenticated && activeTab === "historique") fetchHistory();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab, isAuthenticated]);



  /* ======================================================
     DÉTECTION VIDÉO
     ====================================================== */

  const [videoFile, setVideoFile] = useState(null);
  const [videoResult, setVideoResult] = useState(null);
  const [videoLoading, setVideoLoading] = useState(false);
  const [videoError, setVideoError] = useState("");
  const [videoProgress, setVideoProgress] = useState(0);
  const [videoElapsed, setVideoElapsed] = useState(0);




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
        : selectedModel === "rfdetr-s"
          ? "RF-DETR-S"
          : selectedModel === "dfine-s"
            ? "D-FINE-S"
            : selectedModel === "faster-rcnn"
              ? "Faster R-CNN"
              : selectedModel === "groq-qwen"
                ? "Groq Qwen (Cloud)"
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



  const handleLogin = ({ user, token, rememberMe }) => {

  // Enregistrer les informations de l'utilisateur
  setCurrentUser(user);

  // Enregistrer le token envoyé par Django
  setAuthToken(token);

  // Autoriser l'accès à BirdVision IA
  setIsAuthenticated(true);

  // Réinitialiser la page d'authentification
  setAuthPage("login");

};





  /* ======================================================

     DÉCONNEXION

     ====================================================== */



  const handleLogout = () => {

  // Réinitialiser les données de détection
  handleReset();

  // Supprimer les informations de l'utilisateur
  setCurrentUser(null);

  // Effacer le token Django
  setAuthToken(null);

  // Déconnecter l'utilisateur
  setIsAuthenticated(false);

  // Revenir à la page de connexion
  setAuthPage("home");

};





  /* ======================================================

     CHANGEMENT DU MODÈLE

     ====================================================== */



  const handleModelChange = (event) => {
  const newModel = event.target.value;

  setSelectedModel(newModel);

  // Définir le seuil par défaut selon le modèle
  setConfidenceThreshold(
    newModel === "rfdetr-s" ? 0.09 : 0.25
  );

  // Effacer les anciens résultats
  setResult(null);
  setError("");
};





  /* ======================================================

     SÉLECTION IMAGE

     ====================================================== */



  

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
  `${import.meta.env.VITE_API_URL}/api/detect/`,
  {
    method: "POST",

    // Envoyer le token de l'utilisateur connecté
    headers: {
      Authorization: `Token ${authToken}`,
    },

    // Envoyer l'image et les paramètres IA
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

     SÉLECTION VIDÉO

     ====================================================== */



  const handleVideoChange = (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    const allowed = [
      "video/mp4",
      "video/avi",
      "video/quicktime",
      "video/x-msvideo",
      "video/webm",
    ];
    if (!allowed.includes(file.type)) {
      setVideoError(
        "Veuillez sélectionner une vidéo MP4, AVI, MOV ou WebM."
      );
      return;
    }
    setVideoFile(file);
    setVideoResult(null);
    setVideoError("");
  };



  /* ======================================================

     DÉTECTION VIDÉO

     ====================================================== */



  const handleVideoDetect = async () => {
    if (!videoFile) {
      setVideoError("Veuillez sélectionner une vidéo.");
      return;
    }

    setVideoLoading(true);
    setVideoError("");
    setVideoResult(null);
    setVideoProgress(0);
    setVideoElapsed(0);

    clearInterval(videoTimerRef.current);
    videoTimerRef.current = setInterval(() => {
      setVideoElapsed((e) => e + 1);
    }, 1000);

    const formData = new FormData();
    formData.append("video", videoFile);
    formData.append("confidence", confidenceThreshold.toFixed(2));
    formData.append("model", selectedModel);
    formData.append("frame_step", "15");
    formData.append("max_frames", "7");
    formData.append("async", "1");

    try {
      const response = await fetch(
        `${import.meta.env.VITE_API_URL}/api/detect-video/`,
        {
          method: "POST",
          headers: { Authorization: `Token ${authToken}` },
          body: formData,
        }
      );

      let jobData;
      try {
        jobData = await response.json();
      } catch {
        throw new Error("Le serveur a retourné une réponse invalide.");
      }

      if (!response.ok) {
        throw new Error(
          jobData.error || "Erreur lors du lancement de l'analyse."
        );
      }

      const jobId = jobData.job_id;
      const deadline = Date.now() + 30 * 60 * 1000;

      while (Date.now() < deadline) {
        await new Promise((r) => setTimeout(r, 1500));

        const pollRes = await fetch(
          `${import.meta.env.VITE_API_URL}/api/detect-video/${jobId}/`,
          { headers: { Authorization: `Token ${authToken}` } }
        );
        const pollData = await pollRes.json();

        if (pollData.progress !== undefined) {
          setVideoProgress(pollData.progress);
        }

        if (pollData.status === "done") {
          setVideoResult(pollData);
          break;
        }
        if (pollData.status === "error") {
          throw new Error(pollData.error || "Erreur d'analyse vidéo.");
        }
      }
    } catch (err) {
      console.error("Erreur vidéo BirdVision :", err);
      if (err instanceof TypeError) {
        setVideoError(
          "Impossible de communiquer avec le serveur BirdVision."
        );
      } else {
        setVideoError(
          err.message || "Une erreur est survenue pendant l'analyse vidéo."
        );
      }
    } finally {
      clearInterval(videoTimerRef.current);
      setVideoLoading(false);
    }
  };



  /* ======================================================

     RÉINITIALISER VIDÉO

     ====================================================== */



  const handleVideoReset = () => {
    clearInterval(videoTimerRef.current);
    setVideoFile(null);
    setVideoResult(null);
    setVideoError("");
    setVideoLoading(false);
    setVideoProgress(0);
    setVideoElapsed(0);
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
  if (authPage === "home") {
    return (
      <Home
        onLogin={() => setAuthPage("login")}
        onRegister={() => setAuthPage("register")}
      />
    );
  }

  if (authPage === "register") {
    return (
      <Register
        onGoToLogin={() => setAuthPage("login")}
      />
    );
  }

  return (
    <Login
      onLogin={handleLogin}
      onGoToRegister={() => setAuthPage("register")}
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

              ONGLETS

              ================================================== */}



          <div className="analysis-tabs">
            <button
              className={`analysis-tab${activeTab === "image" ? " analysis-tab--active" : ""}`}
              onClick={() => setActiveTab("image")}
            >
              Image
            </button>
            <button
              className={`analysis-tab${activeTab === "video" ? " analysis-tab--active" : ""}`}
              onClick={() => setActiveTab("video")}
            >
              Vidéo
            </button>
            <button
              className={`analysis-tab${activeTab === "historique" ? " analysis-tab--active" : ""}`}
              onClick={() => setActiveTab("historique")}
            >
              Historique
            </button>
          </div>



          {/* ==================================================

              WORKSPACE IMAGE

              ================================================== */}



          {activeTab === "image" && <div className="workspace">





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

  <option value="rfdetr-s">
    RF-DETR-S
  </option>

  <option value="dfine-s">
    D-FINE-S
  </option>

  <option value="faster-rcnn">
    Faster R-CNN
  </option>

  <option value="groq-qwen">
    Groq Qwen (Cloud)
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
  min={selectedModel === "rfdetr-s" ? "0.09" : "0.10"}
  max="0.90"
  step="0.01"
  value={confidenceThreshold}
  onChange={(event) => {
    setConfidenceThreshold(Number(event.target.value));
    setResult(null);
    setError("");
  }}
  disabled={loading}
/>

                  <div className="confidence-scale">
  <span>{selectedModel === "rfdetr-s" ? "9 %" : "10 %"}</span>
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



          </div>}



          {/* VIDEO WORKSPACE */}



          {activeTab === "video" && (
            <div className="workspace">
              <article className="panel upload-panel">
                <div className="panel-header">
                  <div className="panel-title">
                    <span className="step-number">01</span>
                    <div>
                      <span className="panel-label">VIDÉO SOURCE</span>
                      <h3>Importer une vidéo</h3>
                    </div>
                  </div>
                  <span className="file-type-badge">MP4 / AVI</span>
                </div>

                <label className={videoFile ? "drop-zone has-image" : "drop-zone"}>
                  {videoFile ? (
                    <div className="upload-placeholder">
                      <div className="upload-icon"><span>&#9654;</span></div>
                      <h4>{videoFile.name}</h4>
                      <p>{(videoFile.size / 1024 / 1024).toFixed(1)} MB &middot; Vidéo prête</p>
                      <span className="formats">Cliquer pour changer</span>
                    </div>
                  ) : (
                    <div className="upload-placeholder">
                      <div className="upload-icon"><span>&#9654;</span></div>
                      <h4>Déposez votre vidéo ici</h4>
                      <p>Cliquez pour parcourir vos fichiers et sélectionner une vidéo.</p>
                      <span className="formats">MP4, AVI, MOV ou WebM &middot; max 30 s</span>
                    </div>
                  )}
                  <input
                    ref={videoFileInputRef}
                    type="file"
                    accept="video/mp4,video/avi,video/quicktime,video/x-msvideo,video/webm"
                    onChange={handleVideoChange}
                    disabled={videoLoading}
                    hidden
                  />
                </label>

                <div className="model-settings">
                  <div className="model-settings-header">
                    <div>
                      <span className="panel-label">PARAMÈTRES D'ANALYSE</span>
                      <h4>Modèle de détection</h4>
                    </div>
                    <span className="model-status">AI</span>
                  </div>
                  <div className="selected-model-info">
                    <div className="selected-model-icon">AI</div>
                    <div>
                      <span>Modèle sélectionné</span>
                      <strong>{selectedModelName}</strong>
                    </div>
                  </div>
                  <p className="confidence-help">
                    Le modèle et le seuil de confiance sont partagés avec l'onglet Image.
                  </p>
                </div>

                <button
                  className="primary-button"
                  onClick={handleVideoDetect}
                  disabled={!videoFile || videoLoading}
                >
                  {videoLoading ? (
                    <><span className="button-loader"></span>Analyse vidéo avec {selectedModelName}...</>
                  ) : (
                    <><span className="button-spark">&#10022;</span>Analyser la vidéo avec {selectedModelName}<span className="button-arrow">&rarr;</span></>
                  )}
                </button>

                {(videoResult || videoError) && !videoLoading && (
                  <button className="secondary-button" onClick={handleVideoReset}>
                    Nouvelle analyse
                  </button>
                )}
              </article>

              <article className="panel result-panel">
                <div className="panel-header">
                  <div className="panel-title">
                    <span className="step-number">02</span>
                    <div>
                      <span className="panel-label">RÉSULTAT VIDÉO</span>
                      <h3>Résultat de l'analyse</h3>
                    </div>
                  </div>
                  {videoResult ? (
                    <span className="complete-badge"><span>&#10003;</span>Terminée</span>
                  ) : (
                    <span className="waiting-badge">En attente</span>
                  )}
                </div>

                <div className="result-view">
                  {videoLoading && (
                    <div className="loading-state">
                      <div className="scanner">
                        <div className="scanner-circle"><span>AI</span></div>
                        <div className="scanner-ring"></div>
                      </div>
                      <h4>Analyse vidéo en cours</h4>
                      <p>{selectedModelName} analyse votre vidéo image par image.</p>
                      <div className="progress-track">
                        <div className="progress-bar" style={{ width: Math.round(videoProgress * 100) + "%" }}></div>
                      </div>
                      <span className="loading-caption">
                        {Math.round(videoProgress * 100)} %
                        {" · "}
                        {Math.floor(videoElapsed / 60)}:{String(videoElapsed % 60).padStart(2, "0")}
                      </span>
                    </div>
                  )}
                  {!videoLoading && videoError && (
                    <div className="error-state">
                      <div className="state-icon error-state-icon">!</div>
                      <h4>Analyse impossible</h4>
                      <p>{videoError}</p>
                    </div>
                  )}
                  {!videoLoading && !videoError && !videoResult && (
                    <div className="empty-state">
                      <div className="empty-visual">
                        <div className="focus-corner corner-one"></div>
                        <div className="focus-corner corner-two"></div>
                        <div className="focus-corner corner-three"></div>
                        <div className="focus-corner corner-four"></div>
                        <span>&#9654;</span>
                      </div>
                      <h4>Prêt pour l'analyse vidéo</h4>
                      <p>Sélectionnez une vidéo et lancez l'analyse. Les résultats apparaîtront ici.</p>
                    </div>
                  )}
                  {!videoLoading && !videoError && videoResult && (
                    <>
                      {videoResult.result_video && (
                        <div className="result-image-wrapper">
                          <video
                            src={videoResult.result_video}
                            controls
                            autoPlay
                            loop
                            muted
                            className="result-image"
                            style={{ width: "100%", borderRadius: "8px" }}
                          />
                          <div className="result-image-label">
                            <span></span>Vidéo annotée {selectedModelName}
                          </div>
                        </div>
                      )}
                      <div className="result-message success-result">
                        <div className="result-message-icon">&#10003;</div>
                        <div>
                          <strong>Vidéo analysée avec succès</strong>
                          <span>
                            {videoResult.unique_birds != null
                              ? `${videoResult.unique_birds} oiseau(x) unique(s) · `
                              : ""}
                            {videoResult.total_bird_detections} détection(s) &middot; {videoResult.frames_analyzed}/{videoResult.frames_total} images avec {selectedModelName}.
                          </span>
                        </div>
                      </div>
                    </>
                  )}
                </div>
              </article>
            </div>
          )}



          {/* HISTORIQUE */}
          {activeTab === "historique" && (
            <div className="workspace" style={{ display: "block" }}>
              <article className="panel" style={{ width: "100%" }}>
                <div className="panel-header">
                  <div className="panel-title">
                    <span className="step-number">H</span>
                    <div>
                      <span className="panel-label">BASE DE DONNÉES COMMUNE</span>
                      <h3>Historique des détections</h3>
                    </div>
                  </div>
                  <button className="secondary-button" onClick={fetchHistory} disabled={historyLoading} style={{ padding: "6px 14px", fontSize: "13px" }}>
                    {historyLoading ? "Chargement…" : "↻ Actualiser"}
                  </button>
                </div>

                {historyError && (
                  <div className="error-state" style={{ padding: "16px" }}>
                    <p>{historyError}</p>
                  </div>
                )}

                {!historyLoading && !historyError && history.length === 0 && (
                  <div className="empty-state" style={{ padding: "32px", textAlign: "center" }}>
                    <h4>Aucune détection enregistrée</h4>
                    <p>Les analyses effectuées depuis le Web ou l'application mobile apparaîtront ici.</p>
                  </div>
                )}

                {history.length > 0 && (
                  <div style={{ overflowX: "auto" }}>
                    <table style={{ width: "100%", borderCollapse: "collapse", fontSize: "14px" }}>
                      <thead>
                        <tr style={{ borderBottom: "1px solid rgba(255,255,255,0.1)", textAlign: "left" }}>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>#</th>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>Modèle</th>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>Oiseaux</th>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>Confiance</th>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>Date</th>
                          <th style={{ padding: "10px 12px", color: "var(--text-secondary, #aaa)" }}>Image</th>
                        </tr>
                      </thead>
                      <tbody>
                        {history.map((entry) => (
                          <tr key={entry.id} style={{ borderBottom: "1px solid rgba(255,255,255,0.05)" }}>
                            <td style={{ padding: "10px 12px", color: "#666" }}>{entry.id}</td>
                            <td style={{ padding: "10px 12px" }}>
                              <span className="model-status" style={{ fontSize: "12px" }}>{entry.model}</span>
                            </td>
                            <td style={{ padding: "10px 12px", fontWeight: "700", color: entry.bird_count > 0 ? "#4ade80" : "#aaa" }}>
                              {entry.bird_count}
                            </td>
                            <td style={{ padding: "10px 12px" }}>
                              {Math.round(entry.confidence_threshold * 100)} %
                            </td>
                            <td style={{ padding: "10px 12px", fontSize: "12px", color: "#aaa" }}>
                              {new Date(entry.created_at).toLocaleString("fr-FR")}
                            </td>
                            <td style={{ padding: "10px 12px" }}>
                              {entry.result_image ? (
                                <a href={entry.result_image} target="_blank" rel="noreferrer">
                                  <img src={entry.result_image} alt="résultat" style={{ width: "60px", height: "40px", objectFit: "cover", borderRadius: "4px" }} />
                                </a>
                              ) : "—"}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </article>
            </div>
          )}

          {/* VIDEO STATS */}
          {activeTab === "video" && videoResult && (
            <div className="stats-grid">
              {videoResult.unique_birds != null && (
                <div className="stat-card">
                  <div className="stat-icon">&#128031;</div>
                  <div>
                    <span>Oiseaux uniques</span>
                    <strong>{videoResult.unique_birds}</strong>
                  </div>
                </div>
              )}
              <div className="stat-card">
                <div className="stat-icon">01</div>
                <div>
                  <span>Max oiseaux / image</span>
                  <strong>{videoResult.max_birds_in_frame ?? "—"}</strong>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">&Sigma;</div>
                <div>
                  <span>Détections totales</span>
                  <strong>{videoResult.total_bird_detections ?? "—"}</strong>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">AI</div>
                <div>
                  <span>Modèle IA</span>
                  <strong>{selectedModelName}</strong>
                </div>
              </div>
              <div className="stat-card">
                <div className="stat-icon">{videoResult.frames_analyzed}</div>
                <div>
                  <span>Images analysées</span>
                  <strong>{videoResult.frames_analyzed} / {videoResult.frames_total}</strong>
                </div>
              </div>
            </div>
          )}



          {/* ==================================================

              STATISTIQUES IMAGE

              ================================================== */}



          {activeTab === "image" && <div className="stats-grid">



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



          </div>}





          {/* ==================================================

              DÉTAILS DES DÉTECTIONS

              ================================================== */}



          {activeTab === "image" && result?.detections?.length > 0 && (



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

              RF-DETR-S

            </span>



            <span>

              D-FINE-S

            </span>



            <span>

              Faster R-CNN

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
        <img src={birdVisionLogo} alt="BirdVision IA" />
      </div>

      <div>
        <strong>BirdVision IA</strong>
        <span>Détection intelligente d'oiseaux</span>
      </div>
    </div>

    <div className="footer-company">
      <img
        src={siribraLogo}
        alt="Logo SIRIBRA GROUP"
        className="siribra-logo"
      />

      <div className="footer-company-info">
        <strong>SIRIBRA GROUP</strong>
        <span>TECHNOLOGIE. VISION. IMPACT.</span>
        <small>Entreprise porteuse du projet BirdVision IA</small>
      </div>
    </div>

    <p>
      BirdVision IA • RT-DETR-X • YOLO26s • D-FINE-X • RF-DETR-S • D-FINE-S • Faster R-CNN
    </p>

    </div>
  </footer>
    </div>
  );
}

export default App;
