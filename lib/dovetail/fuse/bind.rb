module Dovetail
  class Fuse
    module Bind
      module_function

      def type_pascal(module_id)
        module_id.to_s.split("_").map { |w| w[0].upcase + w[1..-1].to_s }.join("")
      end

      def generate(module_id)
        pascal = type_pascal(module_id)
        lines = []
        lines << "import { createPanelApi } from '@dovetail/runtime/internal';"
        lines << "import type { #{pascal}ModuleTypes } from '$generated/types/#{module_id}';"
        lines << ""
        lines << "export * from '@dovetail/runtime/components';"
        lines << "export type { Decimal, IsoDate, IsoDateTime, Id, CurrencyCode, Money, Result, CommonErrorCode, OverlayHandle } from '@dovetail/runtime/internal';"
        lines << ""
        lines << "const api = createPanelApi<#{pascal}ModuleTypes>('#{module_id}');"
        lines << ""
        lines << "export const { openOverlay, toast, navigate, link, useRoute, store, emit, on, shortcut, every, after, frame, subscribe, useId, useProps, useContractVersion, t, formatNumber, formatMoney, formatDate, formatPercent } = api;"
        lines.join("\n") + "\n"
      end
    end
  end
end
