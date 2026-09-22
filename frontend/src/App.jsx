import { useState } from "react";
import "./App.css";

function App() {
  // ======================================================
  // ÉTATS
  // ======================================================

  // Image sélectionnée par l'utilisateur
  const [image, setImage] = useState(null);

  // Aperçu local de l'image
  const [preview, setPreview] = useState(null);

  // Résultat retourné par Django
  const [result, setResult] = useState(null);

  // État de chargement pendant l'analyse
  const [loading, setLoading] = useState(false);

  // Message d'erreur
  const [error, setError] = useState("");


  // ======================================================
  // SÉLECTION D'UNE IMAGE
  // ======================================================

  const handleImageChange = (event) => {
    const file = event.target.files[0];

    if (!file) return;

    // Vérification du type de fichier
    const allowedTypes = ["image/jpeg", "image/png"];

    if (!allowedTypes.includes(file.type)) {
      setError("Veuillez sélectionner une image JPG, JPEG ou PNG.");
      return;
    }

    // Supprimer l'ancien aperçu pour éviter de garder
    // inutilement l'ancienne URL en mémoire
    if (preview) {
      URL.revokeObjectURL(preview);
    }

    setImage(file);
    setPreview(URL.createObjectURL(file));

    // Réinitialiser les anciens résultats
    setResult(null);
    setError("");
  };


  // ======================================================
  // ENVOI DE L'IMAGE À DJANGO
  // ======================================================

  const handleDetect = async () => {
    if (!image) {
      setError("Veuillez sélectionner une image.");
      return;
    }

    setLoading(true);
    setError("");
    setResult(null);

    // Création des données envoyées à Django
    const formData = new FormData();

    formData.append("image", image);

    // Seuil de confiance fixé à 70 %
    formData.append("confidence", "0.70");

    try {
      const response = await fetch(
        "http://127.0.0.1:8000/api/detect/",
        {
          method: "POST",
          body: formData,
        }
      );

      // Récupération de la réponse Django
      const data = await response.json();

      // Si Django retourne une erreur
      if (!response.ok) {
        throw new Error(
          data.error ||
            "Une erreur est survenue pendant la détection."
        );
      }

      // Enregistrer le résultat
      setResult(data);
    } catch (err) {
      console.error("Erreur BirdVision :", err);

      setError(
        err.message ||
          "Impossible de communiquer avec le serveur BirdVision."
      );
    } finally {
      setLoading(false);
    }
  };


  // ======================================================
  // INTERFACE
  // ======================================================

  return (
    <div className="app">

      {/* ==================================================
          BARRE DE NAVIGATION
      ================================================== */}

      <header className="navbar">
        <div className="brand">

          <div className="logo">
            B
          </div>

          <div>
            <h1>BirdVision IA</h1>

            <span>
              Intelligence artificielle pour la détection d'oiseaux
            </span>
          </div>

        </div>

        <div className="status">
          <span className="status-dot"></span>
          RT-DETR-X
        </div>
      </header>


      {/* ==================================================
          CONTENU PRINCIPAL
      ================================================== */}

      <main className="container">

        {/* ==================================================
            PRÉSENTATION
        ================================================== */}

        <section className="hero">

          <span className="badge">
            VISION PAR ORDINATEUR
          </span>

          <h2>
            Détectez les oiseaux
            <br />

            <span>
              grâce à l'intelligence artificielle
            </span>
          </h2>

          <p>
            Importez une image et BirdVision IA analysera
            automatiquement son contenu afin de localiser
            les oiseaux présents.
          </p>

        </section>


        {/* ==================================================
            ESPACE DE TRAVAIL
        ================================================== */}

        <section className="workspace">

          {/* ==================================================
              IMPORTATION DE L'IMAGE
          ================================================== */}

          <div className="upload-card">

            <div className="card-header">

              <div>
                <p className="step">
                  ÉTAPE 01
                </p>

                <h3>
                  Importer une image
                </h3>
              </div>

              <span className="confidence">
                Confiance : 70 %
              </span>

            </div>


            {/* Zone d'importation */}

            <label
              className={`drop-zone ${
                preview ? "has-image" : ""
              }`}
            >

              {preview ? (

                <img
                  src={preview}
                  alt="Aperçu sélectionné"
                  className="preview-image"
                />

              ) : (

                <div className="upload-content">

                  <div className="upload-icon">
                    ↑
                  </div>

                  <h4>
                    Sélectionnez une image
                  </h4>

                  <p>
                    Importez une photographie pour lancer
                    l'analyse.
                  </p>

                  <span>
                    JPG, JPEG ou PNG
                  </span>

                </div>

              )}

              <input
                type="file"
                accept="image/png,image/jpeg"
                onChange={handleImageChange}
                hidden
              />

            </label>


            {/* Informations sur le fichier */}

            {image && (

              <div className="file-info">

                <div>

                  <strong>
                    {image.name}
                  </strong>

                  <span>
                    {(image.size / 1024 / 1024).toFixed(2)} MB
                  </span>

                </div>


                <label className="change-button">

                  Changer l'image

                  <input
                    type="file"
                    accept="image/png,image/jpeg"
                    onChange={handleImageChange}
                    hidden
                  />

                </label>

              </div>

            )}


            {/* Bouton de détection */}

            <button
              className="detect-button"
              onClick={handleDetect}
              disabled={!image || loading}
            >

              {loading
                ? "Analyse en cours..."
                : "Détecter les oiseaux"}

            </button>

          </div>


          {/* ==================================================
              RÉSULTAT
          ================================================== */}

          <div className="result-card">

            <div className="card-header">

              <div>

                <p className="step">
                  ÉTAPE 02
                </p>

                <h3>
                  Résultat de l'analyse
                </h3>

              </div>

            </div>


            {/* ==================================================
                ERREUR
            ================================================== */}

            {error && (

              <div className="error-message">

                <strong>
                  Une erreur est survenue
                </strong>

                <p>
                  {error}
                </p>

              </div>

            )}


            {/* ==================================================
                RÉSULTAT DISPONIBLE
            ================================================== */}

            {result ? (

              <div className="result-content">

                <img
                  src={result.result_image}
                  alt="Résultat de la détection des oiseaux"
                  className="result-image"
                />

                <div className="success-message">
                  Analyse terminée avec succès.
                </div>

              </div>

            ) : (

              /* ================================================
                 AUCUN RÉSULTAT
              ================================================ */

              !error && (

                <div className="empty-result">

                  <div className="scan-icon">

                    {loading ? "..." : "◎"}

                  </div>

                  <h4>

                    {loading
                      ? "Analyse en cours..."
                      : "En attente d'analyse"}

                  </h4>

                  <p>

                    {loading
                      ? "RT-DETR-X analyse actuellement votre image."
                      : "Le résultat de la détection apparaîtra ici après l'analyse de votre image."}

                  </p>

                </div>

              )

            )}


            {/* ==================================================
                STATISTIQUES
            ================================================== */}

            <div className="metrics">

              <div className="metric">

                <span>
                  Oiseaux détectés
                </span>

                <strong>
                  {result ? result.bird_count : "—"}
                </strong>

              </div>


              <div className="metric">

                <span>
                  Seuil de confiance
                </span>

                <strong>
                  70 %
                </strong>

              </div>

            </div>


            {/* ==================================================
                DÉTAIL DES DÉTECTIONS
            ================================================== */}

            {result &&
              result.detections &&
              result.detections.length > 0 && (

                <div className="detections-list">

                  <h4>
                    Détails des détections
                  </h4>

                  {result.detections.map(
                    (detection, index) => (

                      <div
                        className="detection-item"
                        key={index}
                      >

                        <span>
                          Oiseau {index + 1}
                        </span>

                        <strong>
                          {(
                            detection.confidence * 100
                          ).toFixed(1)}
                          %
                        </strong>

                      </div>

                    )
                  )}

                </div>

              )}

          </div>

        </section>

      </main>


      {/* ==================================================
          PIED DE PAGE
      ================================================== */}

      <footer>

        <p>
          BirdVision IA • Détection intelligente d'oiseaux
        </p>

        <span>
          RT-DETR-X • Django REST • React
        </span>

      </footer>

    </div>
  );
}

export default App;