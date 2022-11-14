//===- CoverageExporterXml.cpp - Code coverage export --------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements export of code coverage data to XML.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
//
// The xml code coverage export follows the Cobertura format as defined here:
// http://cobertura.sourceforge.net/xml/coverage-04.dtd
//
// Included here for reference:
//
// <!-- Portions (C) International Organization for Standardization 1986:
//      Permission to copy in any form is granted for use with
//      conforming SGML systems and applications as defined in
//      ISO 8879, provided this notice is included in all copies.
// -->
//
//   <!ELEMENT coverage (sources?,packages)>
//   <!ATTLIST coverage line-rate        CDATA #REQUIRED>
//   <!ATTLIST coverage branch-rate      CDATA #REQUIRED>
//   <!ATTLIST coverage lines-covered    CDATA #REQUIRED>
//   <!ATTLIST coverage lines-valid      CDATA #REQUIRED>
//   <!ATTLIST coverage branches-covered CDATA #REQUIRED>
//   <!ATTLIST coverage branches-valid   CDATA #REQUIRED>
//   <!ATTLIST coverage complexity       CDATA #REQUIRED>
//   <!ATTLIST coverage version          CDATA #REQUIRED>
//   <!ATTLIST coverage timestamp        CDATA #REQUIRED>
//
//   <!ELEMENT sources (source*)>
//
//   <!ELEMENT source (#PCDATA)>
//
//   <!ELEMENT packages (package*)>
//
//   <!ELEMENT package (classes)>
//   <!ATTLIST package name        CDATA #REQUIRED>
//   <!ATTLIST package line-rate   CDATA #REQUIRED>
//   <!ATTLIST package branch-rate CDATA #REQUIRED>
//   <!ATTLIST package complexity  CDATA #REQUIRED>
//
//   <!ELEMENT classes (class*)>
//
//   <!ELEMENT class (methods,lines)>
//   <!ATTLIST class name        CDATA #REQUIRED>
//   <!ATTLIST class filename    CDATA #REQUIRED>
//   <!ATTLIST class line-rate   CDATA #REQUIRED>
//   <!ATTLIST class branch-rate CDATA #REQUIRED>
//   <!ATTLIST class complexity  CDATA #REQUIRED>
//
//   <!ELEMENT methods (method*)>
//
//   <!ELEMENT method (lines)>
//   <!ATTLIST method name        CDATA #REQUIRED>
//   <!ATTLIST method signature   CDATA #REQUIRED>
//   <!ATTLIST method line-rate   CDATA #REQUIRED>
//   <!ATTLIST method branch-rate CDATA #REQUIRED>
//   <!ATTLIST method complexity  CDATA #REQUIRED>
//
//   <!ELEMENT lines (line*)>
//
//   <!ELEMENT line (conditions*)>
//   <!ATTLIST line number CDATA #REQUIRED>
//   <!ATTLIST line hits   CDATA #REQUIRED>
//   <!ATTLIST line branch CDATA "false">
//   <!ATTLIST line condition-coverage CDATA "100%">
//
//   <!ELEMENT conditions (condition*)>
//
//   <!ELEMENT condition EMPTY>
//   <!ATTLIST condition number CDATA #REQUIRED>
//   <!ATTLIST condition type CDATA #REQUIRED>
//   <!ATTLIST condition coverage CDATA #REQUIRED>
//
//===----------------------------------------------------------------------===//

#include "CoverageExporterXml.h"
#include "CoverageReport.h"
#include "llvm/Support/NativeFormatting.h"
#include <chrono>
#include <unordered_map>

using namespace llvm;

namespace {

void renderHeader(raw_ostream &OS, const FileCoverageSummary &Totals) {
  OS << "<?xml version='1.0' encoding='UTF-8'?>"
        "<!DOCTYPE coverage SYSTEM "
        "'http://cobertura.sourceforge.net/xml/coverage-04.dtd'>";

  OS << "<coverage";
  OS << " line-rate=\"";
  llvm::write_double(OS, Totals.LineCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " branch-rate=\"";
  llvm::write_double(OS, Totals.BranchCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " lines-covered=\"" << Totals.LineCoverage.getCovered() << "\"";
  OS << " lines-valid=\"" << Totals.LineCoverage.getNumLines() << "\"";
  OS << " branches-covered=\"" << Totals.BranchCoverage.getCovered() << "\"";
  OS << " branches-valid=\"" << Totals.BranchCoverage.getNumBranches() << "\"";
  OS << " function-rate=\"";
  llvm::write_double(OS, Totals.FunctionCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " functions-covered=\"" << Totals.FunctionCoverage.getExecuted()
     << "\"";
  OS << " functions-valid=\"" << Totals.FunctionCoverage.getNumFunctions()
     << "\"";
  OS << " complexity=\"0.0\" version=\"llvm-cov tbd\"";
  OS << " timestamp=\""
     << std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch())
            .count()
     << "\"";
  OS << ">";

  OS << "<sources><source>.</source></sources>";

  OS << "<packages>";

  OS << "<package name=\"\"";
  OS << " line-rate=\"";
  llvm::write_double(OS, Totals.LineCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " branch-rate=\"";
  llvm::write_double(OS, Totals.BranchCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " function-rate=\"";
  llvm::write_double(OS, Totals.FunctionCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " complexity=\"0.0\"";
  OS << ">";

  OS << "<classes>";
}

void renderFooter(raw_ostream &OS) {
  OS << "</classes>";
  OS << "</package>";
  OS << "</packages>";
  OS << "</coverage>";
}

void renderFile(raw_ostream &OS, const coverage::CoverageMapping &Coverage,
                const std::string &Filename,
                const FileCoverageSummary &FileReport,
                const CoverageViewOptions &Options) {
  OS << "<class name=\"\" filename=\"" << Filename << "\"";
  OS << " line-rate=\"";
  llvm::write_double(OS, FileReport.LineCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " branch-rate=\"";
  llvm::write_double(OS, FileReport.BranchCoverage.getPercentCovered() / 100,
                     FloatStyle::Fixed, 5);
  OS << "\"";
  OS << " complexity=\"0.0\"";
  OS << ">";

  OS << "<methods/>";

  OS << "<lines>";

  std::unordered_map<int, uint64_t> LinesNums;

  const auto CovData = Coverage.getCoverageForFile(Filename);
  for (const auto &Segment : CovData) {
    if (!Segment.HasCount)
      continue;

    // TODO: some lines are not reported ok: line 10 from counters.cpp

    const auto It = LinesNums.find(Segment.Line);
    if (It != LinesNums.end()) {
      const auto Count = It->second;
      if (Segment.Count > Count)
        LinesNums[Segment.Line] = Segment.Count;
      continue;
    }

    OS << "<line";
    OS << " number=\"" << Segment.Line << "\"";
    OS << " hits=\"" << Segment.Count << "\"";

    std::vector<const coverage::CountedRegion *> Branches;
    for (const auto &Branch : CovData.getBranches()) {
      if (Branch.Kind ==
              coverage::CounterMappingRegion::RegionKind::BranchRegion &&
          Segment.Line >= Branch.LineStart && Segment.Line <= Branch.LineEnd) {
        Branches.push_back(&Branch);
      }
    }
    if (Branches.empty()) {
      OS << " branch=\"false\"";
    } else {
      const auto Total = Branches.size() * 2;

      auto Notcovered = Total;
      for (const auto *Branch : Branches) {
        if (Branch->ExecutionCount != 0)
          --Notcovered;
        if (Branch->FalseExecutionCount != 0)
          --Notcovered;
      }

      // TODO: some branches are not reported ok: line 16,17 from counters.cpp
      OS << " branch=\"true\"";
      OS << " condition-coverage=\"";
      llvm::write_double(OS, double(Notcovered) / double(Total) * 100.0,
                         FloatStyle::Fixed, 0);
      OS << "% (" << Notcovered << "/" << Total << ")\"";
    }

    OS << "/>";

    LinesNums[Segment.Line] = Segment.Count;
  }

  OS << "</lines>";
  OS << "</class>";
}

void renderFiles(raw_ostream &OS, const coverage::CoverageMapping &Coverage,
                 ArrayRef<std::string> SourceFiles,
                 ArrayRef<FileCoverageSummary> FileReports,
                 const CoverageViewOptions &Options) {
  for (unsigned I = 0, E = SourceFiles.size(); I < E; ++I)
    renderFile(OS, Coverage, SourceFiles[I], FileReports[I], Options);
}

} // end anonymous namespace

void CoverageExporterXml::renderRoot(const CoverageFilters &IgnoreFilters) {
  std::vector<std::string> SourceFiles;
  for (StringRef SF : Coverage.getUniqueSourceFiles()) {
    if (!IgnoreFilters.matchesFilename(SF))
      SourceFiles.emplace_back(SF);
  }
  renderRoot(SourceFiles);
}

void CoverageExporterXml::renderRoot(ArrayRef<std::string> SourceFiles) {
  FileCoverageSummary Totals = FileCoverageSummary("Totals");
  auto FileReports = CoverageReport::prepareFileReports(Coverage, Totals,
                                                        SourceFiles, Options);
  renderHeader(OS, Totals);
  renderFiles(OS, Coverage, SourceFiles, FileReports, Options);
  renderFooter(OS);
}
