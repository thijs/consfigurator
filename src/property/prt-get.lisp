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

(in-package :consfigurator.property.prt-get)
(named-readtables:in-readtable :consfigurator)

;;;; Crux's prt-get(8)

(defun mrun-prt-get (&rest args)
  (apply #'mrun :env env "prt-get" args))

(defun mrun-ports (&rest args)
  (apply #'mrun "ports" args))

(defun get-installed-packages ()
  (or (get-connattr 'installed-packages)
      (setf (get-connattr 'installed-packages)
            (lines (mrun-prt-get "listinst")))))

(defprop installed :posix (&rest packages)
  "Ensure all of the prt-get(8) packages PACKAGES are installed."
  (:desc #?"prt-get(8) installed @{packages}")
  (:hostattrs (os:required 'os:crux))
  (:check (subsetp packages (get-installed-packages) :test #'string=))
  (:apply (mrun-prt-get :inform "depinst" packages)
          (setf (get-connattr 'updatedp) t
                ;; Reset Consfigurator's idea of what's installed, as we don't
                ;; know what additional dependencies were just installed.
                (get-connattr 'installed-packages) nil)))

(defprop deleted :posix (&rest packages)
  "Ensure all of the prt-get(8) packages PACKAGES are removed."
  (:desc #?"prt-get(8) removed @{packages}")
  (:hostattrs (os:required 'os:crux))
  (:check (null (intersection packages (get-installed-packages)
                              :test #'string=)))
  (:apply (mrun-prt-get :inform "remove" packages)
          (setf (get-connattr 'installed-packages)
                (set-difference (get-connattr 'installed-packages) packages
                                :test #'string=))))

(defprop updated :posix ()
  (:desc "Ensure ports are up to date")
  (:hostattrs (os:required 'os:crux))
  (:apply (mrun-ports :inform "-u")))

(defprop upgraded :posix ()
  (:desc "prt-get(8) upgraded")
  (:hostattrs (os:required 'os:crux))
  (:check (prog1 (zerop (mrun-prt-get :for-exit "sysup" "--test"))
            (setf (get-connattr 'updatedp) t)))
  (:apply (mrun-prt-get :inform "sysup")
          (mrun-prt-get :inform "update" "-fr" "$(revdep)")
          ;; Reset Consfigurator's idea of what's installed, as some packages
          ;; may have been removed.
          (setf (get-connattr 'installed-packages) nil)))
