
import { useState } from "react";
import "./Register.css";

import birdVisionLogo from "../assets/birdvision-logo.png";
import loginBackground from "../assets/login-background.png";

function Register({ onGoToLogin }) {
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  // INSCRIPTION AVEC DJANGO
  const handleSubmit = async (event) => {
    event.preventDefault();

    setError("");
    setSuccess("");

    const cleanName = name.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (!cleanName || !cleanEmail || !password || !confirmPassword) {
      setError("Veuillez remplir tous les champs.");
      return;
    }

    if (password.length < 8) {
      setError("Le mot de passe doit contenir au moins 8 caractères.");
      return;
    }

    if (password !== confirmPassword) {
      setError("Les mots de passe ne correspondent pas.");
      return;
    }

    setLoading(true);

    try {
      const response = await fetch(
        "http://127.0.0.1:8000/api/auth/register/",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Accept: "application/json",
          },
          body: JSON.stringify({
            username: cleanName,
            email: cleanEmail,
            password: password,
          }),
        }
      );

      const data = await response.json().catch(() => ({}));

      if (!response.ok) {
        const errorDetails = Array.isArray(data.error)
          ? data.error.join(" ")
          : data.error || data.detail || "Inscription impossible.";

        throw new Error(errorDetails);
      }

      setSuccess(
        "Votre compte a été créé avec succès ! Vous pouvez maintenant vous connecter."
      );

      setPassword("");
      setConfirmPassword("");
    } catch (err) {
      setError(
        err instanceof TypeError
          ? "Impossible de contacter Django. Vérifiez que le serveur fonctionne."
          : err.message || "Une erreur est survenue pendant l'inscription."
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <main
      className="register-page"
      style={{ backgroundImage: `url(${loginBackground})` }}
    >
      <div className="register-overlay"></div>

      <div className="register-container">
        {/* PARTIE GAUCHE */}
        <section className="register-showcase">
          <div className="register-brand">
            <img src={birdVisionLogo} alt="Logo BirdVision IA" />

            <div>
              <h1>
                BirdVision <span>IA</span>
              </h1>
              <p>COMPUTER VISION PLATFORM</p>
            </div>
          </div>

          <div className="register-showcase-content">
            <div className="register-badge">
              INTELLIGENCE ARTIFICIELLE
            </div>

            <h2>
              Observez la nature
              <br />
              <span>autrement.</span>
            </h2>

            <p className="register-description">
              Rejoignez BirdVision IA et découvrez une
              nouvelle manière d'observer et d'analyser
              les oiseaux grâce à la puissance de
              l'intelligence artificielle.
            </p>

            <div className="register-feature">
              Détection intelligente • Computer Vision • IA
            </div>
          </div>

          <div className="register-showcase-footer">
            BirdVision IA — Plateforme intelligente
            d'analyse des oiseaux
          </div>
        </section>

        {/* FORMULAIRE D'INSCRIPTION */}
        <section className="register-card">
          <span className="register-kicker">
            BIENVENUE SUR BIRDVISION IA
          </span>

          <h2>Créer un compte</h2>

          <p className="register-subtitle">
            Inscrivez-vous pour accéder à votre
            espace d'analyse intelligente.
          </p>

          <form className="register-form" onSubmit={handleSubmit}>
            {/* NOM COMPLET */}
            <div className="register-field">
              <label htmlFor="register-name">Nom complet</label>

              <input
                id="register-name"
                type="text"
                placeholder="Votre nom complet"
                value={name}
                onChange={(event) => setName(event.target.value)}
                autoComplete="name"
                required
              />
            </div>

            {/* EMAIL */}
            <div className="register-field">
              <label htmlFor="register-email">Adresse email</label>

              <input
                id="register-email"
                type="email"
                placeholder="exemple@email.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                autoComplete="email"
                required
              />
            </div>

            {/* MOT DE PASSE */}
            <div className="register-field">
              <label htmlFor="register-password">Mot de passe</label>

              <div className="register-password-wrapper">
                <input
                  id="register-password"
                  type={showPassword ? "text" : "password"}
                  placeholder="Votre mot de passe"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  autoComplete="new-password"
                  minLength={8}
                  required
                />

                <button
                  type="button"
                  className="register-password-toggle"
                  onClick={() => setShowPassword(!showPassword)}
                  aria-label={
                    showPassword ? "Masquer le mot de passe" : "Afficher le mot de passe"
                  }
                >
                  {showPassword ? "Masquer" : "Afficher"}
                </button>
              </div>
            </div>

            {/* CONFIRMATION DU MOT DE PASSE */}
            <div className="register-field">
              <label htmlFor="register-confirm">
                Confirmer le mot de passe
              </label>

              <input
                id="register-confirm"
                type="password"
                placeholder="Confirmez votre mot de passe"
                value={confirmPassword}
                onChange={(event) => setConfirmPassword(event.target.value)}
                autoComplete="new-password"
                required
              />
            </div>

            {/* ERREUR */}
            {error && (
              <div className="register-error" role="alert">
                {error}
              </div>
            )}

            {/* SUCCÈS */}
            {success && (
              <div className="register-success" role="status">
                {success}
              </div>
            )}

            {/* BOUTON */}
            <button
              className="register-submit"
              type="submit"
              disabled={loading || Boolean(success)}
            >
              {loading
                ? "Création du compte..."
                : "Créer mon compte →"}
            </button>
          </form>

          {/* RETOUR À LA CONNEXION */}
          <div className="register-login">
            <span>Vous avez déjà un compte ?</span>{" "}

            <button type="button" onClick={onGoToLogin}>
              Se connecter
            </button>
          </div>
        </section>
      </div>
    </main>
  );
}

export default Register;
