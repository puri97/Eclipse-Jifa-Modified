<!--
    Copyright (c) 2022 Contributors to the Eclipse Foundation

    See the NOTICE file(s) distributed with this work for additional
    information regarding copyright ownership.

    This program and the accompanying materials are made available under the
    terms of the Eclipse Public License 2.0 which is available at
    http://www.eclipse.org/legal/epl-2.0

    SPDX-License-Identifier: EPL-2.0
 -->
<template>
  <span>
    <template v-for="part in parts">
      <el-tooltip v-if="part.hints"
                  effect="dark"
                  placement="top-start">
        <div slot="content" style="max-width: 600px">
          <div v-for="line of part.hints" :key="line">
            {{ line }}
          </div>
        </div>
        <span :class="part.class">{{ part.text }}</span>
      </el-tooltip>
      <span v-else :class="part.class">{{ part.text }}</span>
    </template>
  </span>
</template>

<script>

import {formatTime} from "@/util";
import {formatTimePeriod, getCauseHint, getPhaseHint} from "@/components/gclog/GCLogUtil";

export default {
  props: ["metadata", "gcEvent"],
  data() {
    return {
      parts: []
    }
  },
  methods: {
    dealData() {
      this.parts = []

      this.dealDatestamp()
      this.dealUptime()
      this.dealGCID()
      this.dealEventType()
      this.dealCause()
      this.dealSpecialSituation()
      this.dealDuration()
      this.dealMemory()
      this.dealCPUTime()
      this.dealPromotion()
      this.dealReclamation()
      this.dealInterval()

      this.transformParts()
    },
    appendNormalText(s) {
      this.parts.push({text: s})
    },
    dealDatestamp() {
      if (this.gcEvent.startTime >= 0 && this.metadata.timestamp >= 0) {
        this.appendNormalText(formatTime(this.gcEvent.startTime + this.metadata.timestamp, 'Y-M-D h:m:s') + " ");
      }
    },
    dealUptime() {
      if (this.gcEvent.startTime > 0) {
        this.appendNormalText((this.gcEvent.startTime / 1000).toFixed(3) + " ");
      }
    },
    dealGCID() {
      if (this.gcEvent.gcid > 0) {
        this.appendNormalText(this.gcEvent.gcid  + ": ");
      }
    },
    dealCause() {
      const cause = this.gcEvent.cause;
      if (cause) {
        this.appendNormalText("(");
        this.parts.push({
          text: cause,
          hint: [getCauseHint(cause)],
          ...this.getPartProblem("badCauseFullGC", cause)
        })
        this.appendNormalText(") ");
      }
    },
    dealEventType() {
      const type = this.gcEvent.eventType
      if (type) {
        this.parts.push({
          text: type,
          hint: [getPhaseHint(type)],
          ...this.getPartProblem("badEventType", this.gcEvent.eventType)
        })
        this.appendNormalText(" ");
      }
    },

    dealSpecialSituation() {
      const dealFunctions = ["dealInitialMark", "dealPrepareMixed", "dealToSpaceExhausted"]
      const parts = dealFunctions.map(f => this[f]()).filter(p => p)
      if (parts.length > 0) {
        this.appendNormalText("(")
        for (let i = 0; i < parts.length; i++) {
          if (i > 0) {
            this.appendNormalText(", ")
          }
          this.parts.push(parts[i])
        }
        this.appendNormalText(") ")
      }
    },
    dealInitialMark() {
      if (this.gcEvent.INITIAL_MARK) {
        return {
          text: "Initial Mark",
          hint: [getPhaseHint("Initial Mark Situation")]
        }
      }
    },
    dealPrepareMixed() {
      if (this.gcEvent.PREPARE_MIXED) {
        return {
          text: "Prepare Mixed",
          hint: [getPhaseHint("Prepare Mixed Situation")]
        }
      }
    },
    dealToSpaceExhausted() {
      if (this.gcEvent.TO_SPACE_EXHAUSTED) {
        return {
          text: "To-space Exhausted",
          hint: [getCauseHint("To-space Exhausted")],
          ...this.getPartProblem("toSpaceExhausted")
        }
      }
    },
    dealDuration() {
      if (this.gcEvent.duration >= 0) {
        this.appendNormalText(this.$t("jifa.gclog.duration") + ":")
        this.parts.push({
          text: formatTimePeriod(this.gcEvent.duration),
          ...this.getPartProblem("badDuration", this.gcEvent.eventType)
        })
        this.appendNormalText(" ")
      }
    },
    dealMemory() {
      let firstItemFound = false
      const generations = ["young", "old", "humongous", "heap", "archive", "metaspace"]
      if (this.gcEvent.memory) {
        generations.forEach(generation => {
          const item = this.gcEvent.memory[generation];
          if (item === undefined || (item.preUsed < 0 && item.postUsed < 0 && item.total < 0)) {
            return
          }
          if (!firstItemFound) {
            this.appendNormalText(`[${this.$t("jifa.gclog.detail.memory")} `)
          } else {
            this.appendNormalText(" ")
          }
          this.appendNormalText(this.$t("jifa.gclog.generation." + generation) + ":")
          this.dealMemoryPreUsed(item.preUsed, generation)
          this.dealMemoryPreCapacity(item.preCapacity, generation)
          if (item.preUsed >= 0 || item.preCapacity >= 0) {
            this.appendNormalText("->")
          }
          this.dealMemoryPostUsed(item.postUsed, generation)
          this.dealMemoryPostCapacity(item.postCapacity, generation)
          this.appendNormalText(" ")

          firstItemFound = true
        })
        if (firstItemFound) {
          this.appendNormalText("] ")
        }
      }
    },
    dealMemoryPreUsed(value, generation) {
      if (value >= 0) {
        this.parts.push({
          text: this.formatSizeInDetail(value)
        })
      }
    },
    dealMemoryPreCapacity(value, generation) {
      if (value >= 0 && (generation !== "metaspace" || this.metadata.metaspaceCapacityReliable)) {
        this.appendNormalText("(")
        this.parts.push({
          text: this.formatSizeInDetail(value)
        })
        this.appendNormalText(")")
      }
    },
    dealMemoryPostUsed(value, generation) {
      if (value >= 0) {
        let problem = ""
        if (generation === "old") {
          problem = "highOldUsed"
        } else if (generation === 'humongous'){
          problem = "highHumongousUsed"
        } else if (generation === "heap") {
          problem = "highHeapUsed"
        } else if (generation === 'metaspace') {
          problem = "highMetaspaceUsed"
        }
        this.parts.push({
          text: this.formatSizeInDetail(value),
          ...this.getPartProblem(problem)
        })
      }
    },
    dealMemoryPostCapacity(value, generation) {
      if (value >= 0 && (generation !== "metaspace" || this.metadata.metaspaceCapacityReliable)) {
        this.appendNormalText("(")
        let problem = ""
        if (generation === "old") {
          problem = "smallOldGen"
        } else if (generation === 'young'){
          problem = "smallYoungGen"
        }
        this.parts.push({
          text: this.formatSizeInDetail(value),
          ...this.getPartProblem(problem)
        })
        this.appendNormalText(")")
      }
    },
    dealCPUTime() {
      if (this.gcEvent.cputime) {
        this.appendNormalText(`[${this.$t("jifa.gclog.detail.cputime")} `)
        this.dealUser();
        this.dealSys();
        this.dealReal();
        this.appendNormalText("] ")
      }
    },
    dealUser() {
      this.appendNormalText(" User=")
      this.parts.push({
        text: formatTimePeriod(this.gcEvent.cputime.user),
        ...this.getPartProblem("badUsr")
      })
    },
    dealSys() {
      this.appendNormalText(" Sys=")
      this.parts.push({
        text: formatTimePeriod(this.gcEvent.cputime.sys),
        ...this.getPartProblem("badSys")
      })
    },
    dealReal() {
      this.appendNormalText(" Real=")
      const part = {
        text: formatTimePeriod(this.gcEvent.cputime.real),
      }
      this.parts.push(part)
    },
    dealPromotion() {
      if (this.gcEvent.promotion >= 0) {
        this.appendNormalText(this.$t("jifa.gclog.timeGraph.promotion") + ":")
        this.parts.push({
          text: this.formatSizeInDetail(this.gcEvent.promotion),
          ...this.getPartProblem("badPromotion", this.gcEvent.eventType),
        })
        this.appendNormalText(" ")
      }
    },
    dealInterval() {
      if (this.gcEvent.interval >= 0) {
        this.appendNormalText(this.$t("jifa.gclog.detail.interval") + ":")
        this.parts.push({
          text: formatTimePeriod(this.gcEvent.interval),
          ...this.getPartProblem("badInterval", this.gcEvent.eventType),
        })
        this.appendNormalText(" ")
      }
    },
    dealReclamation() {
      if (this.gcEvent.reclamation >= 0) {
        this.appendNormalText(this.$t("jifa.gclog.timeGraph.reclamation") + ":")
        this.parts.push({
          text: this.formatSizeInDetail(this.gcEvent.reclamation)
        })
        this.appendNormalText(" ")
      }
    },
    formatSizeInDetail(size) {
      if (size <= 1024) {
        return 0
      }
      if (size <= 1024 * 1024) {
        return Math.round(size / 1024) + "K"
      }
      return Math.round(size / 1024 / 1024) + "M"
    },
    isNormalText(part) {
      return !part.bad && !part.hint
    },
    transformParts() {
      const combined = []
      this.parts.forEach(part => {
        if (this.isNormalText(part) && combined.length > 0 && this.isNormalText(combined[combined.length - 1])) {
          combined[combined.length - 1].text = combined[combined.length - 1].text + part.text
        } else {
          combined.push(part)
        }
      })

      this.parts = combined.map(part => {
        const r = {
          text: part.text,
          class: part.bad ? "bad-metric" : "",
        }
        const hint = [part.hint, part.problemDescription]
            .flat().filter(s => s).map(s => s.startsWith("jifa.") ? this.$t(s) : s);
        if (hint.length > 0) {
          r.hints = hint
        }
        return r;
      })
    },
    getPartProblem(problemType, descriptionParam) {
      if (problemType === "") {
        return
      }
      const problem = this.gcEvent.diagnose.find(p => p.type === problemType)
      if (problem === undefined) {
        return
      }
      return {
        bad: true,
        problemDescription: this.$t('jifa.gclog.diagnose.abnormal.' + problemType, {param: descriptionParam})
      }
    }
  },
  created() {
    this.dealData()
  }
}
</script>

<style scoped>
.bad-metric {
  color: #E74C3C;
}
</style>