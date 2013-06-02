-- DEFINICAO DE INQUERITO

CREATE TABLE surveys (
  id      INT NOT NULL,
  name    VARCHAR(64),
  date_from  DATE NOT NULL,
  date_to    DATE NOT NULL,
  active    BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY(id)
);

-- EXEMPLO
-- 1, 'INQUERITO TESTE'

CREATE TABLE question_types (
  id      INT NOT NULL,
  name    VARCHAR(32),
  PRIMARY KEY(id)
);

-- EXEMPLO
-- 1, Texto Livre
-- 2, Estrelas
-- 3, Escolha Unica
-- 4, Escolha Multipla

CREATE TABLE questions (
  id          INT NOT NULL,
  survey_id      INT NOT NULL,
  question_type_id  INT NOT NULL,
  description      TEXT NOT NULL, -- TEXTO COM A PERGUNTA
  PRIMARY KEY(id),
  FOREIGN KEY(survey_id) REFERENCES surveys(id),
  FOREIGN KEY(question_type_id) REFERENCES question_types(id)
);

CREATE INDEX questions_survey_id_idx ON questions(survey_id);
CREATE INDEX questions_question_type_id_idx ON questions(question_type_id);

-- EXEMPLO
-- 1, 1, 1, 'Indique o seu prato favorito' TEXTO LIVRE
-- 2, 1, 2, 'Classifique o Restaurante' ESTRELAS

CREATE TABLE question_options (
  id         INT NOT NULL,
  question_id   INT NOT NULL,
  description    TEXT NOT NULL, -- Texto da Opção
  value      INT DEFAULT 0, -- Valor da Opção, opcional pode ou não ser usado.
  PRIMARY KEY(id),
  FOREIGN KEY(question_id) REFERENCES questions(id)
);

CREATE INDEX question_options_question_id_idx ON question_options(question_id);

--EXEMPLO
-- 1, 2, '', 1 -- UMA ESTRELA
-- 1, 2, '', 2 -- DUAS ESTRELAS

-- RESPOSTAS

CREATE TABLE survey_responses ( 
-- O NOME E´ ESTUPIDO MAS NAO ME LEMBREI DE NENHUM MELHOR, REPRESENTA UM CONJUNTO DE RESPOSTAS
-- E AGRUPA OS DADOS CRM COMO TINHAMOS FALADO
  id       INT NOT NULL,
  survey_id  INT NOT NULL,
  tstamp     TIMESTAMP NOT NULL,
  closed    BOOLEAN DEFAULT FALSE,
  email    VARCHAR(64),
  name    VARCHAR(64),
  phone    VARCHAR(64),
  PRIMARY KEY(id),
  FOREIGN KEY(survey_id) REFERENCES surveys(id)
);

-- 1, 1, '2013-06-03 10:40', TRUE, 'carlosnunomota@gmail.com', '', ''

CREATE INDEX survey_responses_survey_id_idx ON survey_responses(survey_id);

CREATE TABLE answers (
  survey_response_id     INT NOT NULL,
  question_id       INT NOT NULL,
  question_option_id     INT DEFAULT NULL, -- USED FOR OPTION ANSWER
  free_text        TEXT DEFAULT NULL, -- USED FOR FREE TEXT ANSWERS
  FOREIGN KEY(survey_response_id) REFERENCES survey_responses(id),
  FOREIGN KEY(question_id) REFERENCES questions(id),
  FOREIGN KEY(question_option_id) REFERENCES question_options(id)
);

CREATE INDEX answers_survey_response_id_idx ON answers(survey_response_id);
CREATE INDEX answers_survey_question_id_idx ON answers(question_id);
CREATE INDEX answers_survey_question_option_id_idx ON answers(question_option_id);

-- 1, 1, NULL, 'Bolonhesa' -- RESPOSTA À PERGUNTA 1 DO INQUERITO 1
-- 1, 2, 2, NULL  -- RESPOSTA À PERGUNTA 2 DO INQUERITO 1 (Duas Estrelas)