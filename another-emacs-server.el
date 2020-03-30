;;; another-emacs-server.el --- An Emacs server built on HTTP and JSON  -*- lexical-binding: t; -*-

;; Copyright (C) 2020  Xu Chunyang

;; Author: Xu Chunyang
;; Homepage: https://github.com/xuchunyang/another-emacs-server
;; Package-Requires: ((emacs "25.1") (web-server "20200312"))
;; Keywords: processes
;; Version: 0

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; An Emacs Server built on HTTP and JSON

;;; Code:

(require 'web-server)
(require 'json)

(defgroup another-emacs-server nil
  "An Emacs Server built on HTTP and JSON."
  :group 'external)

(defcustom another-emacs-server-host "localhost"
  "Host used by the another Emacs server."
  :type 'string)

(defcustom another-emacs-server-port 7777
  "Port used by the another Emacs server."
  :type 'integer)

(defun another-emacs-server--response (process status object)
  "Send JSON response to PROCESS.
STATUS is an HTTP status code.
OBJECT is an Emacs Lisp value, will be encoded in JSON, as response body."
  (let ((json (condition-case err
                  (json-encode object)
                (json-error
                 (json-encode
                  `((error . ,(concat "json-encode: " (error-message-string err)))))))))
    (process-send-string
     process
     (concat
      (format "HTTP/1.1 %d %s\r\n" status (alist-get status ws-status-codes))
      "Content-Type: application/json\r\n"
      (format "Content-Length: %d\r\n" (string-bytes json))
      "\r\n"
      json))))

;;;###autoload
(defun another-emacs-server ()
  "Start the Emacs server."
  (interactive)
  (ws-start
   (lambda (request)
     (with-slots (process context) request
       (let* ((err nil)
              (body
               (pcase context
                 ('application/json
                  (condition-case err1
                      (let ((json-object-type 'alist)
                            (json-key-type 'symbol)
                            (json-array-type 'list)
                            (json-false nil)
                            (json-null nil))
                        (json-read-from-string
                         (substring
                          (oref request pending)
                          (oref request index))))
                    (json-error (setq err (error-message-string err1)))))
                 (_ (setq err "The request body is not in JSON")))))
         (cond
          (err
           (another-emacs-server--response process 400 `((error . ,err))))
          (t
           (cond
            ((assq 'eval body)
             (another-emacs-server--response
              process
              200
              (condition-case err
                  `((result . ,(with-local-quit (eval (read (alist-get 'eval body)) t))))
                (error
                 `((error . ,(error-message-string err)))))))
            ((assq 'file body)
             (let ((files (alist-get 'file body)))
               (cond
                ((stringp files) (setq files (list files)))
                ((listp files) (cl-loop for f in files
                                        unless (stringp f)
                                        do (setq err (format "%S is not a string" f))))
                (t (setq err (format "%S is not a list of files" files))))
               (unless err
                 (ignore-errors (mapc #'find-file files)))
               (another-emacs-server--response
                process
                200
                (cond (err `((error . ,err)))
                      (t   `((result . ,"OK")))))))))))))
   another-emacs-server-port
   nil
   :host another-emacs-server-host))

(provide 'another-emacs-server)
;;; another-emacs-server.el ends here
