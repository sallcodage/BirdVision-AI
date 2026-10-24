
import { useState } from "react";
import "./Login.css";

import birdVisionLogo from "../assets/birdvision-logo.png";
import loginBackground from "../assets/login-background.png";

function Login({ onLogin, onGoToRegister }) {
  // ==========================================
  // ÉTATS DU FORMULAIRE
  // ==========================================

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // ==========================================
  // CONNEXION AVEC DJANGO
  // ==========================================

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError("");

    if (!email.trim() || !password.trim()) {
      setError(
        "Veuillez renseigner votre email et votre mot de passe."
      );
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(
        "http://127.0.0.1:8000/api/auth/login/",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            email: email.trim().toLowerCase(),
            password,
          }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(
          data.error ||
          "Email ou mot de passe incorrect."
        );
      }

      if (!data.token || !data.user) {
        throw new Error(
          "Réponse de connexion incomplète."
        );
      }

      // Transmission de l'utilisateur à App.jsx
      onLogin?.({
        user: data.user,
        token: data.token,
        rememberMe,
      });

    } catch (err) {
      if (err instanceof TypeError) {
        setError(
          "Impossible de contacter Django. Vérifiez que le serveur fonctionne."
        );
      } else {
        setError(
          err.message ||
          "Impossible de vous connecter. Veuillez réessayer."
        );
      }
    } finally {
      setLoading(false);
    }
  };

  // ==========================================
  // INTERFACE
  // ==========================================

  return (
    <main
      className="login-page"
      style={{
        backgroundImage: `url(${loginBackground})`,
      }}
    >
      {/* FOND SOMBRE */}
      <div className="login-overlay"></div>

      {/* LUMIÈRES DÉCORATIVES */}
      <div className="login-glow login-glow-one"></div>
      <div className="login-glow login-glow-two"></div>

      <div className="login-container">

        {/* ===================================
            PARTIE GAUCHE
        ==================================== */}

        <section className="login-showcase">

          {/* LOGO ET NOM */}
          <div className="login-showcase-brand">

            <div className="showcase-logo">
              <img
                src={birdVisionLogo}
                alt="Logo BirdVision IA"
              />
            </div>

            <div>
              <h1>
                BirdVision <span>IA</span>
              </h1>

              <p>Computer Vision Platform</p>
            </div>

          </div>

          {/* PRÉSENTATION */}
          <div className="showcase-content">

            <div className="showcase-badge">
              <span></span>
              INTELLIGENCE ARTIFICIELLE
            </div>

            <h2>
              Observez la nature
              <br />
              <span>autrement.</span>
            </h2>

            <p className="showcase-description">
              Découvrez une nouvelle manière d'observer
              et d'analyser les oiseaux grâce à la
              puissance de l'intelligence artificielle.
            </p>

            {/* FONCTIONNALITÉS */}
            <div className="showcase-features">

              <div className="showcase-feature">
                <div className="showcase-feature-icon">
                  <span>AI</span>
                </div>

                <div>
                  <strong>Détection intelligente</strong>
                  <p>
                    Localisez automatiquement les oiseaux
                    présents dans vos images.
                  </p>
                </div>
              </div>

              <div className="showcase-feature">
                <div className="showcase-feature-icon">
                  <span>CV</span>
                </div>

                <div>
                  <strong>Vision par ordinateur</strong>
                  <p>
                    Analysez vos photographies avec
                    des technologies avancées.
                  </p>
                </div>
              </div>

              <div className="showcase-feature">
                <div className="showcase-feature-icon">
                  <span>RT</span>
                </div>

                <div>
                  <strong>Modèles d'intelligence artificielle</strong>
                  <p>
                    Exploitez RT-DETR-X, YOLO26s
                    et D-FINE-X pour vos analyses.
                  </p>
                </div>
              </div>

            </div>

          </div>

          {/* BAS DE LA PARTIE GAUCHE */}
          <div className="showcase-footer">
            <span className="showcase-status-dot"></span>
            Système de détection opérationnel
          </div>

        </section>

        {/* ===================================
            PARTIE DROITE
            FORMULAIRE DE CONNEXION
        ==================================== */}

        <section className="login-card">

          {/* EN-TÊTE */}
          <div className="login-card-top">

            <div className="login-mobile-brand">
              <img
                src={birdVisionLogo}
                alt="BirdVision IA"
              />

              <span>BirdVision IA</span>
            </div>

            <div className="login-security">
              <span>●</span>
              Accès sécurisé
            </div>

          </div>

          {/* TITRE */}
          <div className="login-heading">

            <span className="login-kicker">
              BIENVENUE SUR BIRDVISION IA
            </span>

            <h2>Connexion</h2>

            <p>
              Connectez-vous à votre espace pour
              commencer vos analyses intelligentes.
            </p>

          </div>

          {/* FORMULAIRE */}
          <form
            className="login-form"
            onSubmit={handleSubmit}
          >

            {/* EMAIL */}
            <div className="form-group">

              <label htmlFor="login-email">
                Adresse email
              </label>

              <div className="input-wrapper">

                <input
                  id="login-email"
                  type="email"
                  placeholder="exemple@email.com"
                  value={email}
                  onChange={(event) =>
                    setEmail(event.target.value)
                  }
                  autoComplete="email"
                  required
                />

              </div>

            </div>

            {/* MOT DE PASSE */}
            <div className="form-group">

              <label htmlFor="login-password">
                Mot de passe
              </label>

              <div className="input-wrapper password-wrapper">

                <input
                  id="login-password"
                  type={
                    showPassword
                      ? "text"
                      : "password"
                  }
                  placeholder="Entrez votre mot de passe"
                  value={password}
                  onChange={(event) =>
                    setPassword(event.target.value)
                  }
                  autoComplete="current-password"
                  required
                />

                <button
                  type="button"
                  className="password-toggle"
                  onClick={() =>
                    setShowPassword(!showPassword)
                  }
                  aria-label={
                    showPassword
                      ? "Masquer le mot de passe"
                      : "Afficher le mot de passe"
                  }
                >
                  {showPassword
                    ? "Masquer"
                    : "Afficher"}
                </button>

              </div>

            </div>

            {/* SE SOUVENIR DE MOI */}
            <div className="login-options">

              <label className="remember-me">

                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(event) =>
                    setRememberMe(event.target.checked)
                  }
                />

                <span>Se souvenir de moi</span>

              </label>

            </div>

            {/* ERREUR */}
            {error && (
              <div
                className="login-error"
                role="alert"
              >
                {error}
              </div>
            )}

            {/* BOUTON CONNEXION */}
            <button
              type="submit"
              className="login-button"
              disabled={loading}
            >
              {loading ? (
                <>
                  <span className="button-loader"></span>
                  Connexion en cours...
                </>
              ) : (
                <>
                  Se connecter
                  <span>→</span>
                </>
              )}
            </button>

          </form>

          {/* SÉPARATEUR */}
          <div className="login-divider">
            <span>OU</span>
          </div>

          {/* INSCRIPTION */}
          <div
            className="login-register-section"
            style={{
              textAlign: "center",
              marginTop: "18px",
            }}
          >

            <p
              style={{
                color: "#64748b",
                fontSize: "14px",
                marginBottom: "12px",
              }}
            >
              Vous n'avez pas encore de compte ?
            </p>

            <button
              type="button"
              onClick={onGoToRegister}
              style={{
                width: "100%",
                padding: "14px 18px",
                background: "transparent",
                color: "#0891b2",
                border: "1px solid #0891b2",
                borderRadius: "10px",
                fontWeight: "700",
                fontSize: "14px",
                cursor: "pointer",
              }}
            >
              Créer un compte →
            </button>

          </div>

          {/* INFORMATIONS */}
          <div className="login-info">

            <p>
              BirdVision IA est une plateforme
              intelligente de détection et de
              comptage des oiseaux.
            </p>

          </div>

          {/* PIED DE CARTE */}
          <div className="login-card-footer">

            <span>
              © {new Date().getFullYear()} BirdVision IA
            </span>

            <span>
              Computer Vision Platform
            </span>

          </div>

        </section>

      </div>
    </main>
  );
}

export default Login;
