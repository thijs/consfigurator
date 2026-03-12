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

(in-package :consfigurator.property.dir)
(named-readtables:in-readtable :consfigurator)

(defprop snapshot-extracted :posix
    (snapshot-name directory
                   &key replace
                   &aux (dest
                         (merge-pathnames snapshot-name
                                          (ensure-directory-pathname directory))))
  "Extract a tarball as produced by DATA:DIR-SNAPSHOT under DIRECTORY.
If REPLACE, delete and replace the snapshot (or anything else) that already
exists at DIRECTORY/SNAPSHOT-NAME.  This is useful to ensure the latest
available version of the snapshot is present on the remote system."
  ;; TODO Keyword argument to replace only if a newer version of the
  ;; prerequisite data is available.
  (:desc (declare (ignore replace dest))
         #?"dir snapshot ${snapshot-name} extracted to ${directory}")
  (:hostattrs (declare (ignore replace dest))
              (require-data "--dir-snapshot" snapshot-name))
  (:check (and (not replace) (remote-exists-p dest)))
  (:apply
   (when replace
     (delete-remote-trees directory)
     (ensure-directories-exist directory))
   (file:directory-exists directory)
   (with-remote-current-directory (directory)
     (mrun :input (get-data-stream "--dir-snapshot" snapshot-name)
           "tar" (if (zerop (get-connattr :remote-uid)) "oxfz" "xfz") "-")))
  (:unapply
   (declare (ignore replace))
   (delete-remote-trees dest)))
