import { useEffect, useState } from "react";
import "./App.css";

function App() {
  const [image, setImage] = useState(null);
  const [preview, setPreview] = useState(null);

  const [result, setResult] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // ======================================================
  // NETTOYAGE DE L'APERÇU
  // ======================================================

  useEffect(() => {
    return () => {
      if (preview) {
        URL.revokeObjectURL(preview);
      }
    };
  }, [preview]);

  // ======================================================
  // SÉLECTION D'UNE IMAGE
  // ======================================================

  const handleImageChange = (event) => {
    const file = event.target.files?.[0];

    if (!file) return;

    const allowedTypes = ["image/jpeg", "image/png"];

    if (!allowedTypes.includes(file.type)) {
      setError("Veuillez sélectionner une image JPG, JPEG ou PNG.");
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

  // ======================================================
  // DÉTECTION
  // ======================================================

  const handleDetect = async () => {
    if (!image) {
      setError("Veuillez sélectionner une image.");
      return;
    }

    setLoading(true);
    setError("");
    setResult(null);

    const formData = new FormData();

    formData.append("image", image);
    formData.append("confidence", "0.70");

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
      console.error("Erreur BirdVision :", err);

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

  // ======================================================
  // ANALYSER UNE AUTRE IMAGE
  // ======================================================

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

  // ======================================================
  // INTERFACE
  // ======================================================

  return (
    <div className="app">
      {/* NAVIGATION */}

      <header className="navbar">
        <div className="brand">
          <div className="logo">B</div>

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

      {/* CONTENU */}

      <main className="container">
        {/* HERO */}

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
            automatiquement son contenu afin de localiser les
            oiseaux présents.
          </p>
        </section>

        {/* ESPACE DE TRAVAIL */}

        <section className="workspace">
          {/* IMPORTATION */}

          <div className="upload-card">
            <div className="card-header">
              <div>
                <p className="step">ÉTAPE 01</p>
                <h3>Importer une image</h3>
              </div>

              <span className="confidence">
                Confiance : 70 %
              </span>
            </div>

            {/* ZONE IMAGE */}

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
                  <div className="upload-icon">↑</div>

                  <h4>Sélectionnez une image</h4>

                  <p>
                    Importez une photographie pour lancer
                    l'analyse.
                  </p>

                  <span>JPG, JPEG ou PNG</span>
                </div>
              )}

              <input
                type="file"
                accept="image/png,image/jpeg"
                onChange={handleImageChange}
                disabled={loading}
                hidden
              />
            </label>

            {/* INFORMATIONS IMAGE */}

            {image && (
              <div className="file-info">
                <div>
                  <strong>{image.name}</strong>

                  <span>
                    {(image.size / 1024 / 1024).toFixed(2)} MB
                  </span>
                </div>

                {!loading && (
                  <label className="change-button">
                    Changer l'image

                    <input
                      type="file"
                      accept="image/png,image/jpeg"
                      onChange={handleImageChange}
                      hidden
                    />
                  </label>
                )}
              </div>
            )}

            {/* BOUTON DÉTECTION */}

            <button
              className="detect-button"
              onClick={handleDetect}
              disabled={!image || loading}
            >
              {loading
                ? "Analyse en cours..."
                : "Détecter les oiseaux"}
            </button>

            {/* NOUVELLE ANALYSE */}

            {(result || error) && !loading && (
              <button
                className="reset-button"
                onClick={handleReset}
              >
                Analyser une autre image
              </button>
            )}
          </div>

          {/* RÉSULTAT */}

          <div className="result-card">
            <div className="card-header">
              <div>
                <p className="step">ÉTAPE 02</p>
                <h3>Résultat de l'analyse</h3>
              </div>

              {result && (
                <span className="analysis-status">
                  Analyse terminée
                </span>
              )}
            </div>

            {/* CHARGEMENT */}

            {loading && (
              <div className="loading-result">
                <div className="loader"></div>

                <h4>Analyse en cours</h4>

                <p>
                  RT-DETR-X recherche les oiseaux présents dans
                  votre image.
                </p>

                <span>
                  Cette opération peut prendre quelques secondes.
                </span>
              </div>
            )}

            {/* ERREUR */}

            {!loading && error && (
              <div className="error-message">
                <div className="error-icon">!</div>

                <strong>Une erreur est survenue</strong>

                <p>{error}</p>
              </div>
            )}

            {/* AUCUN RÉSULTAT */}

            {!loading && !error && !result && (
              <div className="empty-result">
                <div className="scan-icon">◎</div>

                <h4>En attente d'analyse</h4>

                <p>
                  Le résultat de la détection apparaîtra ici
                  après l'analyse de votre image.
                </p>
              </div>
            )}

            {/* OISEAUX DÉTECTÉS */}

            {!loading &&
              !error &&
              result &&
              result.bird_count > 0 && (
                <div className="result-content">
                  {result.result_image && (
                    <img
                      src={result.result_image}
                      alt="Résultat de la détection"
                      className="result-image"
                    />
                  )}

                  <div className="success-message">
                    <strong>
                      {result.bird_count}{" "}
                      {result.bird_count === 1
                        ? "oiseau détecté"
                        : "oiseaux détectés"}
                    </strong>

                    <span>
                      Détection réalisée avec un seuil minimum
                      de 70 %.
                    </span>
                  </div>
                </div>
              )}

            {/* AUCUN OISEAU */}

            {!loading &&
              !error &&
              result &&
              result.bird_count === 0 && (
                <div className="no-bird-result">
                  {result.result_image && (
                    <img
                      src={result.result_image}
                      alt="Image analysée"
                      className="result-image"
                    />
                  )}

                  <div className="no-bird-message">
                    <div className="no-bird-icon">○</div>

                    <h4>Aucun oiseau détecté</h4>

                    <p>
                      BirdVision IA n'a trouvé aucun oiseau avec
                      une confiance supérieure ou égale à 70 %.
                    </p>
                  </div>
                </div>
              )}

            {/* STATISTIQUES */}

            <div className="metrics">
              <div className="metric">
                <span>Oiseaux détectés</span>

                <strong>
                  {result ? result.bird_count : "—"}
                </strong>
              </div>

              <div className="metric">
                <span>Seuil de confiance</span>

                <strong>70 %</strong>
              </div>
            </div>

            {/* DÉTAILS */}

            {result &&
              result.detections &&
              result.detections.length > 0 && (
                <div className="detections-list">
                  <div className="detections-header">
                    <h4>Détails des détections</h4>

                    <span>
                      {result.detections.length} résultat(s)
                    </span>
                  </div>

                  {result.detections.map(
                    (detection, index) => (
                      <div
                        className="detection-item"
                        key={index}
                      >
                        <div className="detection-name">
                          <span className="bird-number">
                            {index + 1}
                          </span>

                          <span>
                            Oiseau {index + 1}
                          </span>
                        </div>

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

      {/* FOOTER */}

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