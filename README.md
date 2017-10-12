## TomoTherapy MVCT Dose Calculator

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2015, University of Wisconsin Board of Regents

The TomoTherapy&reg; MVCT Dose Calculator Tool is a GUI based standalone application written in MATLAB&reg; that facilitates estimation of the dose delivered during Mega-Voltage CT (MVCT) acquisition on a [TomoTherapy](http://www.accuray.com) Treatment System. 

Users can load a DICOM CT and RT Structure Set or a patient archive CT and structure set as patient inputs, drag to select a scan length and pitch, input an Image Value to Density Table (IVDT), then select from a list of provided beam models and calculate dose.  The MVCT acquisition may be further modified by adjusting the MLC sinogram, beam output, gantry period, and jaw width to study customized scanning scenarios.  The resulting dose calculation and Dose Volume Histogram (DVH) are displayed and available for export.

TomoTherapy is a registered trademark of Accuray Incorporated. MATLAB is a registered trademark of MathWorks Inc. 

## Contents

* [Installation and Use](README.md#installation-and-use)
* [Compatibility and Requirements](README.md#compatibility-and-requirements)
* [Troubleshooting](README.md#troubleshooting)
* [Default IVDT](README.md#default-ivdt)
* [Loading Patient Archives](README.md#loading-patient-archives)
* [Loading Structure Sets](README.md#loading-structure-sets)
* [Beam Model Selection](README.md#beam-model-selection)
* [Customized Sinograms](README.md#customized-sinograms)
* [Exporting Results](README.md#exporting-results)
  * [Dose Volume Histogram](README.md#dose-volume-histograms)
  * [DICOM RT Dose Image](README.md#dicom-rt-dose-image)
* [License](README.md#license)

## Installation and Use

To install the TomoTherapy MVCT Dose Calculator Tool as a MATLAB App, download and execute the `MVCT Dose Calculator.mlappinstall` file from this directory. If using git, execute `git clone --recursive https://github.com/mwgeurts/mvct_dose`.  Then, create a folder (the default is `./GPU`) and copy each beam model into it.  To change the location of this folder, edit the line `handles.modeldir = './GPU';` in the function `MVCTdose_OpeningFcn()`.

Next, the TomoTherapy MVCT Dose Calculator Tool must be configured to either calculate dose locally or communicate with a dose calculation server.  If using local calculation, `gpusadose` must be installed in an execution path available to MATLAB. If using a remote server, open `CalcDose()`, find the statement `ssh2 = ssh2_config('tomo-research', 'tomo', 'hi-art');`, and enter the IP/DNS address of the dose computation server (tomo-research, for example), a user account on the server (tomo), and password (hi-art).  This user account must have SSH access rights, rights to execute `gpusadose`, and finally read/write acces to the temp directory.  See Accuray Incorporated to see if your research workstation includes this feature.  For additional information, see the [tomo_extract](https://github.com/mwgeurts/tomo_extract) submodule.

To run this application, call `MVCTdose` from MATLAB.  Once the application interface loads, select browse under inputs to load the CT and structure set inputs. Then enter the remaining inputs and click "Calculate Dose".

## Compatibility and Requirements

This application has been validated using TomoTherapy version 4.2 and 5.0 patient archives on Macintosh OSX 10.10 (Yosemite) and MATLAB version 8.4 and 8.5.  Exported DICOM RT Dose images have been validated in MIM version 6.4.  Only HFS CT images have been tested at this time.

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encountered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.

## Default IVDT

This repository includes a default IVDT (ivdt.txt) that is loaded upon application startup.  To edit the location of this file, edit the line `fid = fopen('ivdt.txt', 'r');` in `MVCTdose_OpeningFcn()`.  This file may be modified to change the default IVDT so long as the following format is retained, where the CT numbers range from 0 to 4095 and the density values are in g/cm<sup>3</sup>. Each value must be separated by whitespace (space, \b or \t).  When displayed in the MVCT Dose Calculator Tool, the CT numbers are converted to Hounsfield Units (HU) by subtracting 1024.

```
calibration.ctNums=0 29 340 519 1027 1244 1465 1831 2226 4095
calibration.densVals=0 0.001 0.29 0.46 1 1.153 1.335 1.561 1.824 4.59
```

When loading a TomoTherapy patient archive, the IVDT used by the plan is automatically loaded into the MVCT Dose Calculator Tool.  These values may be edited prior to dose calculation by selecting and modifying existing values or adding additional rows to the table.  The tool will automatically re-sort the table by HU value.  Prior to calculation, both the HU and density values must be in ascending order (a negative density slope is not permitted).

## Loading Patient Archives

To load a TomoTherapy patient archive, after clicking Browse under "Select Image Set" change the file type to Patient Archive (*.xml).  Then, navigate to and select the _patient.xml file in the patient archive.  The tool will scan the archive for all approved treatment plans, and if multiple are found, prompt the user to select which plan to load. The CT image, structure set, and IVDT will then be loaded from the treatment plan.

Finally, all scheduled MVCT procedures for the selected plan will be parsed from the archive and populated in the Slice Selection dropdown menu on the application interface.  The procedures will be listed by the scan acquisition start and end IEC-Y values. Selecting one of these values from the dropdown menu will update the slice selection image to reflect the scan actually performed on that day.  In this manner, this tool may be used to estimate the actual dose delivered to a patient as a result of the slices selected by the radiation therapists.

## Loading Structure Sets

When loading structures, each structure is compared to a pre-loaded atlas (see [structure_atlas](https://github.com/mwgeurts/structure_atlas) for more information).  Structures that match known exclusions (planning structures, etc) are not loaded. Structures that do not match any atlas names are still loaded and given an initial Dx value of 50%. The atlas also contains default Dx values for each structure.  To load all structures, edit the load flags in the atlas to 1.

## Beam Model Selection

As described above, multiple beam models may be loaded into the MVCT Dose Calculator Tool to enable the user to investigate different beam energies or other model-specific parameters. These files will be copied to the computation server along with the plan files at the time of program execution.  Each beam model must be contained within a unique folder under the model folder and contain the following beam model files:

* dcom.header
* lft.img
* penumbra.img
* kernel.img
* fat.img

## Customized Sinograms

By default, the MVCT Dose Calculator Tool assumes the MVCT is acquired with all MLC leaves open.  However, customized MLC leaf pattern may be used for dose calculation.  To use a custom leaf pattern, select a beam model and click the radio button labelled "Custom Sinogram". Two inputs will become available: a file browser (to select the MLC sinogram) and projection rate.  

The custom sinogram file must be a binary file containing 64 x n leaf open times, where n is the number of projections.  Each leaf open time can be single (32-bit) or double (64-bit), big or little endian, and must be between zero (leaf closed) and one (leaf open).  The recommended format is single little endian values. The projection rate value will determine the length of each projection, and the scan length/gantry period will determine the total number of projections needed.  

If the provided sinogram contains fewer projections than what is needed based on the scan selection, the remaining projections will assume all leaves are closed.  If the provided sinogram contains more projections, the sinogram will be truncated based on the length needed to deliver the scan.

## Exporting Results

Following dose calculation, a dose viewer will appear allowing the user to slice through the transverse, coronal, or sagittal slices and view the dose distribution.  If structures are also loaded, a dose volume histogram will be plotted and a list of each structure will be provided along with Dx/Vx values.  The Dx values can be edited.  In addition, "Export DVH" and "Export Dose" buttons will become available to export the results.

### Dose Volume Histogram

The dose volume histogram can saved as a .csv file by clicking "Export DVH".  A window will appear prompting the user to select the file name and path to save the file.

The first row of the DVH Excel file starts with a hash symbol (#) with the file name written in the second column.  The second row lists each structure, structure number (in parentheses), and structure volume (in cc) in 2 on. For all remaining rows, the normalized cumulative dose histogram is reported, with the first column containing the dose bin (in Gy) and each subsequent column containing the relative volume percentage for that dose.  The tool will always compute 1001 bins equally spaced between zero and the maximum dose.

Finally, it should be noted that this tool currently does not consider partial voxels, and will therefore differ slightly from other treatment planning systems in volume or DVH calculation.

### DICOM RT Dose Image

The dose image can be saved as a DICOM RT Dose file by clicking "Export Dose". A window will appear prompting the user to select the file name and path to save the file. The DICOM header is set using the following fields, followed by the 3D dose image as uint16 elements.

| Tag ID | Tag Name | Value |
|--------|----------|-------|
| 0002,0001 | [OB] File Meta Information Version | 00\01 |
| 0002,0010 | [UI] Transfer Syntax UID | 1.2.840.10008.1.2 |
| 0002,0012 | [UI] Implementation Class UID | 1.2.40.0.13.1.1 |
| 0002,0013 | [SH] Implementation Version Name | dcm4che-2.0 |
| 0008,0005 | [CS] Specific Character Set | ISO_IR 100 |
| 0002,0002 | [UI] Media Storage SOP Class UID | 1.2.840.10008.5.1.4.1.1.481.2 |
| 0008,0016 | [UI] SOP Class UID | 1.2.840.10008.5.1.4.1.1.481.2 |
| 0008,0060 | [CS] Modality | RTDOSE |
| 0002,0003 | [UI] Media Storage SOP Instance UID | unique UID determined via `dicomuid` |
| 0008,0018 | [UI] SOP Instance UID | same unique UID as above |
| 0008,0022 | [DA] Acquisition Date | current date |
| 0008,0032 | [TM] Acquisition Time | current time |
| 0008,0012 | [DA] Instance Creation Date | current date |
| 0008,0013 | [TM] Instance Creation Time | current time |
| 0008,0008 | [CS] Image Type | ORIGINAL/PRIMARY/AXIAL |
| 0008,0070 | [LO] Manufacturer | MATLAB `version` |
| 0008,1090 | [LO] Manufacturer’s Model Name | WriteDICOMDose |
| 0018,1020 | [LO] Software Version | WriteDICOMDose (1.0) `version` | 
| 0008,103E | [LO] Series Description | Same series description as CT |
| 0008,1140 | [SQ] Referenced Image Sequence | Class and instance UIDs of CT |
| 0010,0010 | [PN] Patient’s Name | Name from CT or patient archive |
| 0010,0020 | [LO] Patient ID | ID from CT or patient archive |
| 0010,0030 | [DA] Patient’s Birth Date | Birth date from CT or patient archive |
| 0010,0040 | [CS] Patient’s Sex | Sex from CT or patient archive |
| 0010,1010 | [AS] Patient’s Age | Age from CT or patient archive |
| 0018,0050 | [DS] Slice Thickness | IEC-Y thickness, in mm |
| 0020,000D | [UI] Study Instance UID | Study UID of CT |
| 0020,000E | [UI] Series Instance UID | Series UID of CT |
| 0020,0032 | [DS] Image Position | Start coordinates, in mm |
| 0020,0052 | [UI] Frame of Reference UID | FOR UID from CT |
| 0020,1002 | [IS] Images in Acquisition | 1 |
| 0028,0004 | [CS] Photometric Interpretation | MONOCHROME2 |
| 0020,1041 | [DS] Slice Location | IEC-Y of first slice, in mm |
| 0028,0008 | [IS] Number of Frames | Number of IEC-Y voxels |
| 3004,000C | [DS] Grid Frame Offset Vector | IEC-Y values relative to first slice, in mm |
| 0028,0010 | [US] Rows | Number of IEC-Z voxels |
| 0028,0011 | [US] Columns | Number of IEC-X voxels |
| 0028,0030 | [DS] Pixel Spacing | X/Z thickness, in mm |
| 0028,0100 | [US] Bits Allocated | 16 |
| 0028,0101 | [US] Bits Stored | 16 |
| 0028,0102 | [US] High Bit | 15 |
| 0028,0103 | [US] Pixel Representation | 0 |
| 3004,0002 | [CS] Dose Units | GY |
| 3004,0004 | [CS] Dose Type | PHYSICAL |
| 3004,0014 | [CS] Tissue Heterogeneity Correction | ROI_OVERRIDE |
| 3004,000E | [DS] Dose Grid Scaling | Conversion of image value (uint16) to dose (Gy) |

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
