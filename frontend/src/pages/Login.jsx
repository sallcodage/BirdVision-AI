import { useState } from "react";
import "./Login.css";

import birdVisionLogo from "../assets/birdvision-logo.png";
import loginBackground from "../assets/login-background.png";

function Login({ onLogin }) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();

    setError("");

    if (!email.trim() || !password.trim()) {
      setError("Veuillez renseigner votre email et votre mot de passe.");
      return;
    }

    setLoading(true);

    try {
      /*
        Pour l'instant, nous préparons l'interface.

        Ensuite, nous remplacerons cette partie
        par la vraie authentification Django.
      */

      await new Promise((resolve) => setTimeout(resolve, 800));

      if (onLogin) {
        onLogin({
          email,
          rememberMe,
        });
      }
    } catch (err) {
      setError("Impossible de vous connecter. Veuillez réessayer.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main
      className="login-page"
      style={{
        backgroundImage: `url(${loginBackground})`,
      }}
    >
      {/* Couche sombre sur l'image */}
      <div className="login-overlay"></div>

      {/* Lumières décoratives */}
      <div className="login-glow login-glow-one"></div>
      <div className="login-glow login-glow-two"></div>

      <div className="login-container">

        {/* ================================
            PARTIE GAUCHE
        ================================= */}
        <section className="login-showcase">

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
              Une plateforme intelligente de vision par ordinateur
              conçue pour détecter automatiquement les oiseaux
              à partir d'images grâce à l'intelligence artificielle.
            </p>

            <div className="showcase-features">

              <div className="showcase-feature">
                <div className="feature-symbol">
                  AI
                </div>

                <div>
                  <strong>Détection intelligente</strong>
                  <span>
                    Identification automatique des oiseaux
                  </span>
                </div>
              </div>

              <div className="showcase-feature">
                <div className="feature-symbol">
                  CV
                </div>

                <div>
                  <strong>Computer Vision</strong>
                  <span>
                    Analyse précise des images
                  </span>
                </div>
              </div>

              <div className="showcase-feature">
                <div className="feature-symbol">
                  RT
                </div>

                <div>
                  <strong>RT-DETR</strong>
                  <span>
                    Modèle de détection performant
                  </span>
                </div>
              </div>

            </div>

          </div>

          <div className="showcase-footer">
            <span className="showcase-footer-dot"></span>

            Système de détection opérationnel
          </div>

        </section>


        {/* ================================
            PARTIE DROITE : LOGIN
        ================================= */}
        <section className="login-card">

          <div className="login-card-top">

            <div className="mobile-logo">
              <img
                src={birdVisionLogo}
                alt="BirdVision IA"
              />
            </div>

            <div className="login-security">
              <span className="security-dot"></span>
              Accès sécurisé
            </div>

          </div>


          <div className="login-heading">

            <span className="login-kicker">
              BIRDVISION IA
            </span>

            <h2>Bienvenue</h2>

            <p>
              Connectez-vous pour accéder à votre
              espace d'analyse intelligent.
            </p>

          </div>


          <form
            className="login-form"
            onSubmit={handleSubmit}
          >

            {/* EMAIL */}
            <div className="form-group">

              <label htmlFor="email">
                Adresse email
              </label>

              <div className="input-wrapper">

                <div className="input-icon">
                  @
                </div>

                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(event) =>
                    setEmail(event.target.value)
                  }
                  placeholder="votre@email.com"
                  autoComplete="email"
                />

              </div>

            </div>


            {/* MOT DE PASSE */}
            <div className="form-group">

              <div className="password-label">

                <label htmlFor="password">
                  Mot de passe
                </label>

                <button
                  type="button"
                  className="forgot-password"
                  onClick={() =>
                    alert(
                      "La récupération du mot de passe sera ajoutée prochainement."
                    )
                  }
                >
                  Mot de passe oublié ?
                </button>

              </div>


              <div className="input-wrapper">

                <div className="input-icon">
                  •••
                </div>

                <input
                  id="password"
                  type={
                    showPassword
                      ? "text"
                      : "password"
                  }
                  value={password}
                  onChange={(event) =>
                    setPassword(event.target.value)
                  }
                  placeholder="Votre mot de passe"
                  autoComplete="current-password"
                />

                <button
                  type="button"
                  className="password-toggle"
                  onClick={() =>
                    setShowPassword(
                      (previous) => !previous
                    )
                  }
                  aria-label={
                    showPassword
                      ? "Masquer le mot de passe"
                      : "Afficher le mot de passe"
                  }
                >
                  {showPassword ? "Masquer" : "Afficher"}
                </button>

              </div>

            </div>


            {/* OPTIONS */}
            <div className="login-options">

              <label className="remember-me">

                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(event) =>
                    setRememberMe(
                      event.target.checked
                    )
                  }
                />

                <span className="custom-checkbox">
                  {rememberMe ? "✓" : ""}
                </span>

                <span>
                  Se souvenir de moi
                </span>

              </label>

            </div>


            {/* ERREUR */}
            {error && (
              <div className="login-error">
                <div className="error-symbol">
                  !
                </div>

                <span>{error}</span>
              </div>
            )}


            {/* BOUTON */}
            <button
              type="submit"
              className="login-button"
              disabled={loading}
            >

              {loading ? (
                <>
                  <span className="login-spinner"></span>
                  Connexion...
                </>
              ) : (
                <>
                  <span>Se connecter</span>
                  <span className="login-arrow">
                    →
                  </span>
                </>
              )}

            </button>

          </form>


          {/* SÉPARATEUR */}
          <div className="login-divider">
            <span></span>

            <p>PLATEFORME SÉCURISÉE</p>

            <span></span>
          </div>


          {/* INFORMATIONS */}
          <div className="login-info">

            <div className="login-info-icon">
              AI
            </div>

            <div>
              <strong>
                Analyse propulsée par l'IA
              </strong>

              <p>
                BirdVision utilise la vision par ordinateur
                pour analyser vos images.
              </p>
            </div>

          </div>


          <div className="login-card-footer">
            <span>
              BirdVision IA
            </span>

            <span className="footer-separator">
              •
            </span>

            <span>
              Intelligence Artificielle
            </span>
          </div>

        </section>

      </div>
    </main>
  );
}

export default Login;