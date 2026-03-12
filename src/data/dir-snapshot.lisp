;;; Consfigurator -- Lisp declarative configuration management system

;;; Copyright (C) 2026  Thijs Oppermann <thijso@gmail.com>

;;; This file is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3, or (at your option)
;;; any later version.

;;; This file is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.

;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

(in-package :consfigurator.data.dir-snapshot)
(named-readtables:in-readtable :consfigurator)

(defmethod register-data-source ((type (eql :dir-snapshot))
                                 &key name location)
  "Provide tarball snapshots of a directory tree.
Provides prerequisite data identified by \"--dir-snapshot\", \"NAME\".
"
  (when (data-source-providing-p "--dir-snapshot" name)
    (simple-program-error
     "Another data source is providing dir snapshots identified by ~S." name))
  (unless (cl-fad:directory-exists-p location)
    (missing-data-source "~A not found." location))
  (let* ((cached
           (get-highest-local-cached-prerequisite-data "--dir-snapshot" name))
         (cached-version (and cached (nth 1 (split-string (data-version cached)
                                                          :separator ".")))))
    (when cached
      (setf (data-mime cached) "application/gzip"))
    (labels ((latest-version (dirsha)
               (format nil "~A.~A" (get-universal-time) dirsha))
             (check (iden1 iden2)
               (and (string= iden1 "--dir-snapshot")
                    (string= iden2 name)
                    (let ((dirsha (digest-dir location)))
                      (if (and cached-version (string= cached-version dirsha))
                          (data-version cached)
                          (latest-version dirsha)))))
             (extract (&rest ignore)
               (declare (ignore ignore))
               (let* ((dirsha (digest-dir location))
                      (version (latest-version dirsha))
                      (path (local-data-pathname
                             "--dir-snapshot" name version)))
                 (if (and cached-version (string= cached-version dirsha))
                     cached
                     (progn
                       (ignore-errors
                        (mapc #'delete-file
                              (directory-files
                               (pathname-directory-pathname path))))
                       (make-tar-snapshot name location path)
                       (setq cached-version dirsha
                             cached (make-instance 'file-data
                                                   :file path
                                                   :mime "application/gzip"
                                                   :iden1 "--dir-snapshot"
                                                   :iden2 name
                                                   :version version)))))))
      (cons #'check #'extract))))

(defun make-tar-snapshot (name location output)
  (run-program
   `("tar" "-C" ,(namestring location) "-cz" "-f" ,(namestring output) "./")))

(defun digest-dir (dir)
  (if dir
      (digest-sum-files :md5 (list-all-dir-files dir))
      "0"))

(defun digest-sum-files (digest-name files)
  (unless files
    (error "no files given to digest"))
  (let ((out (make-array '(0) :element-type 'base-char
                              :fill-pointer 0 :adjustable t)))
    (with-output-to-string (md5-list out)
      (loop with buffer = (make-array 8192 :element-type '(unsigned-byte 8))
            with digest = (make-array (ironclad:digest-length digest-name)
                                      :element-type '(unsigned-byte 8))
            for file in files
            for digester = (ironclad:make-digest digest-name)
              then (reinitialize-instance digester)
            do (ironclad:digest-file digester file :buffer buffer :digest digest)
               (format md5-list "~A~A;" (file-namestring file)
                       (ironclad:byte-array-to-hex-string digest))))
    (ironclad:byte-array-to-hex-string
     (ironclad:digest-sequence
      :md5
      (ironclad:ascii-string-to-byte-array out)))))


(defun directory-p (pathname)
  (probe-file (format nil "~a/." pathname)))

(defun list-all-dir-files (dir)
  (let (list)
    (cl-fad:walk-directory
     dir
     #'(lambda (fn)
         (when (not (directory-p fn))
           (push fn list)))
     :directories t)
    list))
